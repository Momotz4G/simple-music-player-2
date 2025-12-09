import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:simple_music_player_2/services/metrics_service.dart';

class RemoteControlService {
  static final RemoteControlService _instance =
      RemoteControlService._internal();
  factory RemoteControlService() => _instance;
  RemoteControlService._internal();

  String? _userId;
  bool _isListening = false;
  StreamSubscription<QuerySnapshot>? _commandSubscription;
  DateTime? _lastCommandTime; // Rate Limiter

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
      print("⚠️ RemoteControl: UserId is null in startListening. Waiting...");
      // Wait a bit and try again (up to 5s)
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_userId != null) break;
      }
      if (_userId == null) {
        print(
            "❌ RemoteControl: Cannot listen, userId is still null after wait.");
        return;
      }
    }
    if (_isListening) return;

    print("📡 RemoteControl: Listening for commands for $_userId");

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

          if (action != null) {
            // RATE LIMITER (Prevent Spam Crashes)
            final now = DateTime.now();
            if (_lastCommandTime != null &&
                now.difference(_lastCommandTime!) <
                    const Duration(milliseconds: 150)) {
              print("🛡️ Command Throttled (Too Fast): $action");
            } else {
              _lastCommandTime = now;
              print("📲 COMMAND RECEIVED: $action ($value)");
              onCommand(action, value);
            }
          }

          // Delete immediately
          docChange.doc.reference.delete().then((_) {
            print("🗑️ Command processed & deleted.");
          }).catchError((e) {
            print("⚠️ Failed to delete command: $e");
          });
        }
      }
    });

    _isListening = true;
  }

  void stopListening() {
    _commandSubscription?.cancel();
    _isListening = false;
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
                  print(
                      "⚠️ Art too large to send remote: ${bytes.length} bytes");
                }
              }
            } catch (e) {
              print("⚠️ Failed to extract art for remote: $e");
            }
          }
        } else {
          // If we have online URL or no file, clear local cache logic for safety?
          // No, keep cache in case we switch back fast, but maybe unnecessary.
        }

        await FirebaseFirestore.instance
            .collection('metrics')
            .doc(_userId)
            .collection('remote_state')
            .doc('current')
            .set({
          'title': title ?? "Unknown Title",
          'artist': artist ?? "Unknown Artist",
          'isPlaying': isPlaying,
          'volume': volume,
          'position': positionSeconds,
          'duration': durationSeconds,
          'artUrl': finalArtUrl,
          'last_updated': FieldValue.serverTimestamp(),
        });
        // debugPrint("📡 Remote State Broadcasted");
      } catch (e) {
        debugPrint("⚠️ Remote Broadcast Error: $e");
      }
    });
  }
}
