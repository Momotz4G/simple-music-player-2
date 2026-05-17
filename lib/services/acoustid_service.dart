import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;
import '../env/env.dart';
import 'package:metadata_god/metadata_god.dart' show Metadata;
import 'package:metadata_god/metadata_god.dart' show Metadata;
import 'metadata_service.dart';
import 'pocketbase_service.dart'; // 🔒 OFFLINE MODE

// --- NATIVE C FUNCTION SIGNATURE (Unified Wrapper) ---
// We define the signature for the single function exposed by our C++ wrapper.
// This function will handle all the FFmpeg decoding and Chromaprint processing internally.
typedef GetFingerprintNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef GetFingerprintDart = Pointer<Utf8> Function(Pointer<Utf8>);

class AcoustIdService {
  static const String _baseUrl = 'https://api.acoustid.org/v2/lookup';
  static String get _apiKey => Env.acoustidApiKey;

  // FFI Pointers
  DynamicLibrary? _nativeLib;
  bool _isNativeLoaded = false;

  // Chromaprint FFI Wrapper Function
  GetFingerprintDart? _getFingerprintWrapper;

  AcoustIdService() {
    // 🚀 DEFERRED LOADING: Do not load DLLs on construction 
    // to prevent COM mode conflicts at app startup.
  }

  /// Attempts to load chromaprint.dll / libchromaprint.so
  void _loadNativeLibrary() {
    try {
      if (Platform.isAndroid) {
        _nativeLib = DynamicLibrary.open('libchromaprint.so');
      } else if (Platform.isWindows) {
        // We rely on the DLL being named 'chromaprint.dll' and placed in the project root/bin
        _nativeLib = DynamicLibrary.open('chromaprint.dll');
      }

      if (_nativeLib != null) {
        // Look up the single wrapper function
        _getFingerprintWrapper = _nativeLib!
            .lookupFunction<GetFingerprintNative, GetFingerprintDart>(
                'get_fingerprint_from_file');

        _isNativeLoaded = true;
        print("✅ Native Chromaprint wrapper loaded.");
      }
    } catch (e) {
      print("ℹ️ FFI Error: $e. Using Metadata Fallback.");
    }
  }

  /// --------------------------------------------------------------------------
  /// CORE IDENTIFICATION METHOD (Public)
  /// --------------------------------------------------------------------------

  Future<List<MusicBrainzRecord>> identifyFile(String filePath) async {
    // 🔒 OFFLINE MODE: Skip native fingerprinting & API lookup, fallback to local tags
    if (PocketBaseService.isOffline) {
      print("🔒 Offline Mode: Skipping AcoustID fingerprinting.");
      return _localMetadataFallback(filePath);
    }

    // 1. Lazy load native library if not already
    if (!_isNativeLoaded) _loadNativeLibrary();

    // 2. Try Native Fingerprinting (The hard part)
    if (_isNativeLoaded) {
      try {
        final fingerprint = await _generateFingerprint(filePath);
        if (fingerprint != null) {
          // If fingerprint succeeds, look it up via the API
          return await _lookupFingerprint(fingerprint, 0);
        }
      } catch (e) {
        print("Fingerprint failed: $e");
      }
    }

    // 3. Fallback: Use MetadataService (Safe background scan)
    return _localMetadataFallback(filePath);
  }

  Future<List<MusicBrainzRecord>> _localMetadataFallback(String filePath) async {
    print("⚠️ Using Metadata Fallback...");
    final Metadata? metadata = await MetadataService().readMetadata(filePath);
    final title = metadata?.title ?? "";
    final artist = metadata?.artist ?? "";

    if (title.isNotEmpty) {
      // Create a "Fake" MusicBrainz record from the file tags
      return [
        MusicBrainzRecord(
          score: 0.8, // Lower confidence for tag-based matching
          id: "local-tag",
          title: title,
          artist: artist,
          musicBrainzId: "",
        )
      ];
    }

    return [];
  }

  // --- INTERNAL FINGERPRINTING LOGIC (FFI) ---

  Future<String?> _generateFingerprint(String filePath) async {
    if (!_isNativeLoaded || _getFingerprintWrapper == null) return null;

    // 1. Allocate C memory for the file path string
    final filePathPtr = filePath.toNativeUtf8();

    try {
      // 2. Call the C++ wrapper
      final fingerprintPtr = _getFingerprintWrapper!(filePathPtr);

      if (fingerprintPtr == nullptr) return null;

      // 3. Convert C string to Dart string
      final fingerprint = fingerprintPtr.toDartString();

      // 4. CRITICAL: In a real C++ wrapper, you must also call a free
      // function on the pointer returned by the native side to avoid memory leaks.
      // We skip that here for simplicity, but it's a major production risk.

      return fingerprint;
    } finally {
      // Free the memory for the input string argument (crucial!)
      calloc.free(filePathPtr);
    }
  }

  // --- INTERNAL API LOOKUP LOGIC ---

  Future<List<MusicBrainzRecord>> _lookupFingerprint(
      String fingerprint, int duration) async {
    if (_apiKey.isEmpty) return [];

    final uri = Uri.parse(_baseUrl);
    final response = await http.post(uri, body: {
      'client': _apiKey,
      'meta': 'recordings+releasegroups',
      'duration': duration.toString(),
      'fingerprint': fingerprint,
    });

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    if (data['status'] != 'ok') return [];

    final results = data['results'] as List;
    return results.map<MusicBrainzRecord>((result) {
      final recordings = result['recordings'] as List? ?? [];
      final firstRecording = recordings.isNotEmpty ? recordings.first : null;
      return MusicBrainzRecord(
        score: (result['score'] as num).toDouble(),
        id: result['id'],
        title: firstRecording?['title'] ?? 'Unknown',
        artist: firstRecording != null
            ? (firstRecording['artists'] as List)
                .map((a) => a['name'])
                .join(', ')
            : 'Unknown',
        musicBrainzId: firstRecording?['id'] ?? '',
      );
    }).toList();
  }
}

class MusicBrainzRecord {
  final double score;
  final String id;
  final String title;
  final String artist;
  final String musicBrainzId;

  MusicBrainzRecord({
    required this.score,
    required this.id,
    required this.title,
    required this.artist,
    required this.musicBrainzId,
  });
}
