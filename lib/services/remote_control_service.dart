import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:http/http.dart' as http;
import 'package:simple_music_player_2/services/metrics_service.dart';
import '../env/env.dart';

class RemoteControlService {
  static final RemoteControlService _instance =
      RemoteControlService._internal();
  factory RemoteControlService() => _instance;
  RemoteControlService._internal();

  // REST API Config (For Windows)
  static final String _firestoreBaseUrl =
      'https://firestore.googleapis.com/v1/projects/${Env.firebaseProjectId}/databases/(default)/documents';

  String? _userId;
  bool _isListening = false;
  StreamSubscription<QuerySnapshot>? _commandSubscription;
  Timer? _pollingTimer; // For Windows REST Polling
  DateTime? _lastCommandTime; // Rate Limiter

  // DEDUPLICATION CACHE
  final Set<String> _processedIds = {};

  // Local Art Cache
  String? _cachedArtPath;
  String? _cachedArtBase64;

  // Debounce for broadcasting state
  Timer? _debounceTimer;

  Future<void> init() async {
    // We wait for MetricsService to be ready as it holds the authority on UserID
    final metrics = MetricsService();
    // Wait slightly if metrics isn't initialized (rare race condition)
    int retries = 0;
    while (!metrics.initialized && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    _userId = metrics.userId;
    if (_userId != null) {
      debugPrint("📡 RemoteControl: Initialized with ID: $_userId");
    } else {
      debugPrint(
          "⚠️ RemoteControl: Failed to get User ID from MetricsService.");
    }
  }

  void setUserId(String id) {
    _userId = id;
  }

  // Start listening for commands
  Future<void> startListening(
      {required Function(String action, dynamic value) onCommand}) async {
    if (_userId == null) {
      // debugPrint("⚠️ RemoteControl: UserId is null in startListening. Waiting...");
      // Wait a bit and try again (up to 5s)
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_userId != null) break;
      }
      if (_userId == null) {
        // debugPrint("❌ RemoteControl: Cannot listen, userId is still null after wait.");
        return;
      }
    }
    if (_isListening) return;

    debugPrint(
        "📡 RemoteControl: Listening for commands for $_userId (Mode: ${Platform.isWindows ? 'Polling' : 'Stream'})");

    if (Platform.isWindows) {
      _startPolling(onCommand);
    } else {
      _startNativeListening(onCommand);
    }

    _isListening = true;
  }

  void _startNativeListening(Function(String action, dynamic value) onCommand) {
    final collection = FirebaseFirestore.instance
        .collection('metrics')
        .doc(_userId)
        .collection('remote_commands');

    _commandSubscription = collection.snapshots().listen((snapshot) {
      for (final docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final data = docChange.doc.data() as Map<String, dynamic>;
          final action = data['action'] as String?;
          final value = data['value'];
          _processCommand(action, value, onCommand, docChange.doc.reference);
        }
      }
    });
  }

  void _startPolling(Function(String action, dynamic value) onCommand) {
    _pollingTimer?.cancel();
    // Polling every 1 second
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isListening || _userId == null) {
        timer.cancel();
        return;
      }
      await _pollCommandsRest(onCommand);
    });
  }

  Future<void> _pollCommandsRest(
      Function(String action, dynamic value) onCommand) async {
    try {
      final url =
          Uri.parse('$_firestoreBaseUrl/metrics/$_userId/remote_commands');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json.containsKey('documents')) {
          final documents = json['documents'] as List;
          for (final doc in documents) {
            final fields = doc['fields'];
            final name = doc['name'] as String; // Full path
            // Extract ID from full path ".../remote_commands/DOC_ID"
            final docId = name.split('/').last;

            // DEDUPLICATION CHECK
            if (_processedIds.contains(docId)) {
              // We've already handled this, but it hasn't been deleted yet.
              // Just try to delete it again to be safe.
              _restDelete('metrics/$_userId/remote_commands/$docId');
              continue;
            }

            final action = fields['action']?['stringValue'];
            // Value could be string, int, double
            dynamic value;
            if (fields['value'] != null) {
              final valMap = fields['value'] as Map;
              if (valMap.containsKey('stringValue'))
                value = valMap['stringValue'];
              else if (valMap.containsKey('integerValue'))
                value = int.parse(valMap['integerValue']);
              else if (valMap.containsKey('doubleValue'))
                value = valMap['doubleValue'];
              else if (valMap.containsKey('booleanValue'))
                value = valMap['booleanValue'];
            }

            // Process
            _processCommand(action, value, onCommand, null, restDocId: docId);
          }
        }
      }
    } catch (e) {
      // Silent error
    }
  }

  void _processCommand(String? action, dynamic value,
      Function(String, dynamic) onCommand, DocumentReference? ref,
      {String? restDocId}) {
    if (restDocId != null) {
      _processedIds.add(restDocId);
      // Prune set if it gets too big (rare)
      if (_processedIds.length > 50) {
        _processedIds
            .clear(); // Reset cache periodically to save RAM, safe enough
        _processedIds.add(restDocId);
      }
    }

    if (action != null) {
      // MINIMAL RATE LIMITER (Just prevents accidental Double-Tap < 50ms)
      // Removed the 150ms throttle that was blocking legitimate fast taps
      final now = DateTime.now();
      if (_lastCommandTime != null &&
          now.difference(_lastCommandTime!) <
              const Duration(milliseconds: 50)) {
        // debugPrint("🛡️ Command Micro-Throttled: $action");
      } else {
        _lastCommandTime = now;
        debugPrint(
            "📲 REMOTE COMMAND: $action ($value)"); // Log only successful
        onCommand(action, value);
      }
    }

    // Delete
    if (Platform.isWindows && restDocId != null) {
      _restDelete('metrics/$_userId/remote_commands/$restDocId');
    } else if (ref != null) {
      ref.delete().catchError((e) => debugPrint("⚠️ Failed to delete cmd: $e"));
    }
  }

  void stopListening() {
    _commandSubscription?.cancel();
    _pollingTimer?.cancel();
    _isListening = false;
  }

  // REST Helpers for Windows
  Future<void> _restWrite(
      String collectionPath, String docId, Map<String, dynamic> fields,
      {bool isUpdate = false}) async {
    final firestoreFields = <String, dynamic>{};
    fields.forEach((key, value) {
      firestoreFields[key] = _toFirestoreValue(value);
    });

    final url = Uri.parse(
        '$_firestoreBaseUrl/$collectionPath/$docId${isUpdate ? '?updateMask.fieldPaths=${fields.keys.join('&updateMask.fieldPaths=')}' : ''}');

    try {
      await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': firestoreFields}),
      );
    } catch (e) {
      // Silent
    }
  }

  Future<void> _restDelete(String docPath) async {
    final url = Uri.parse('$_firestoreBaseUrl/$docPath');
    try {
      await http.delete(url);
    } catch (e) {
      // Silent
    }
  }

  dynamic _toFirestoreValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    // Timestamp handling for REST (ISO string)
    if (value is String && value == "SERVER_TIMESTAMP") {
      return {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    }
    if (value == null) return {'nullValue': null};
    return {'stringValue': value.toString()};
  }

  // Broadcast current player state to Firestore
  void broadcastState({
    required String? title,
    required String? artist,
    required bool isPlaying,
    required double volume,
    required int positionSeconds,
    required int durationSeconds,
    String? artUrl,
    String? filePath,
  }) {
    if (_userId == null) return;

    // Debounce updates to avoid write spam (Firestore cost & performance)
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final currentArtUrl = artUrl;

        // EXTRACT LOCAL ART IF ONLINE URL IS MISSING
        String? finalArtUrl = currentArtUrl;

        if ((finalArtUrl == null || finalArtUrl.isEmpty) && filePath != null) {
          // Check Cache
          if (_cachedArtPath == filePath) {
            finalArtUrl = _cachedArtBase64;
          } else {
            // Read New Metadata
            _cachedArtPath = filePath;
            _cachedArtBase64 = null; // Reset

            try {
              final metadata = await MetadataGod.readMetadata(file: filePath);
              if (metadata?.picture != null) {
                final bytes = metadata!.picture!.data;
                // Limit size to avoid Firestore crash (Target < 800KB safe limit)
                if (bytes.length < 800 * 1024) {
                  final base64String = base64Encode(bytes);
                  _cachedArtBase64 =
                      "data:image/jpeg;base64,$base64String"; // Assume jpeg/png compat
                  finalArtUrl = _cachedArtBase64;
                } else {
                  // print("⚠️ Art too large to send remote: ${bytes.length} bytes");
                }
              }
            } catch (e) {
              // print("⚠️ Failed to extract art for remote: $e");
            }
          }
        }

        final data = {
          'title': title ?? "Unknown Title",
          'artist': artist ?? "Unknown Artist",
          'isPlaying': isPlaying,
          'volume': volume,
          'position': positionSeconds,
          'duration': durationSeconds,
          'artUrl': finalArtUrl,
          'last_updated': Platform.isWindows
              ? "SERVER_TIMESTAMP"
              : FieldValue.serverTimestamp(),
        };

        if (Platform.isWindows) {
          // For "current state", we overwrite (isUpdate: false = SET behavior)
          // debugPrint("📡 Broadcasting: Playing=$isPlaying");
          await _restWrite('metrics/$_userId/remote_state', 'current', data,
              isUpdate: false);
        } else {
          await FirebaseFirestore.instance
              .collection('metrics')
              .doc(_userId)
              .collection('remote_state')
              .doc('current')
              .set(data);
        }

        // debugPrint("📡 Remote State Broadcasted");
      } catch (e) {
        // debugPrint("⚠️ Remote Broadcast Error: $e");
      }
    });
  }
}
