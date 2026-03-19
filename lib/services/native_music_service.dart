import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; // 🚀 IMPORT
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'debug_log_service.dart';
import 'dart:isolate'; // 🚀 IMPORT ISOLATE
import 'dart:ui'; // 🚀 IMPORT UI for IsolateNameServer
import 'package:flutter/widgets.dart'; // 🚀 For WidgetsBinding

import 'package:audio_service/audio_service.dart'; // 🚀 IMPORT
import 'audio_handler.dart'; // 🚀 IMPORT
import 'package:metadata_god/metadata_god.dart';
import '../models/song_model.dart';
import 'flac_downloader_service.dart'; // 🚀 IMPORT FOR VALIDATION
import 'package:rxdart/rxdart.dart'; // 🚀 IMPORT RXDART FOR STREAM SWITCHING
// Env not needed locally

class NativeMusicService {
  // Singleton pattern - ensures same player instance everywhere
  static final NativeMusicService _instance = NativeMusicService._internal();
  factory NativeMusicService() => _instance;
  static int _instanceCount = 0;
  bool _isZombie = true; // Default to Zombie until we are RESUMED
  final ReceivePort _mutexPort = ReceivePort();
  final String _mutexName = 'simple_music_player_audio_mutex';
  bool _hasClaimedMutex = false;
  
  // 🚀 Preload tracking to avoid redundant loads during crossfade
  String? _preloadedFilePath;
  SongModel? _preloadedSong;

  // 🚀 Subject to track the active player for dynamic stream switching
  final BehaviorSubject<AudioPlayer> _activePlayerSubject = BehaviorSubject<AudioPlayer>();

  // 🚀 Loading guard to prevent race conditions
  bool _isLoading = false;
  Completer<void>? _loadingCompleter;

  NativeMusicService._internal() {
    _instanceCount++;
    _activePlayerSubject.add(_player1); // Initialize subject with default player
    
    DebugLogService().info(
        "NativeMusicService Created. Count=$_instanceCount Hash=${hashCode} PID=${pid} Isolate=${Isolate.current.debugName} InitialState=ZOMBIE");

    // 🚀 INITIALIZE AUDIO HANDLER (Mobile Only)
    _setupListeners(1);
    _setupListeners(2);

    if (Platform.isAndroid || Platform.isIOS) {
      _initAudioHandler();
    }

    // 🚀 LIFECYCLE MUTEX: Only claim the throne when we are VISIBLE (Resumed)
    // This prevents background ghosts from stealing the audio focus.

    // 1. Register Observer
    final observer = _NativeLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(observer);

    // 2. Check initial state (in case we are already resumed)
    // 🚀 ON DESKTOP: We don't need to wait for resumed state. Claim immediately.
    if (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _tryClaimMutex();
    }
  }

  void _tryClaimMutex() {
    if (_hasClaimedMutex) return; // Already King

    DebugLogService()
        .info("NativeMusicService: App READY. Claiming Mutex/Audio Throne...");

    // Kill existing holder
    final existingPort = IsolateNameServer.lookupPortByName(_mutexName);
    if (existingPort != null) {
      DebugLogService().info(
          "NativeMusicService: Found existing instance. Sending DIE command.");
      existingPort.send('DIE');
      IsolateNameServer.removePortNameMapping(_mutexName);
    }

    // Register my port
    IsolateNameServer.registerPortWithName(_mutexPort.sendPort, _mutexName);

    // Enable Audio
    _isZombie = false;
    _hasClaimedMutex = true;
    DebugLogService()
        .info("NativeMusicService: Mutex Claimed. I am the AUDIO MASTER.");

    // Listen for usurpation
    _mutexPort.listen((message) {
      if (message == 'DIE') {
        DebugLogService().error(
            "NativeMusicService: Received DIE command! I have been replaced.");
        _becomeZombie();
      }
    });

    _ensureSessionInitialized();
  }

  void _becomeZombie() {
    _isZombie = true;
    _hasClaimedMutex = false;
    try {
      _player.stop();
    } catch (e) {
      DebugLogService().error("Error stopping during zombification: $e");
    }
    DebugLogService().info("NativeMusicService: Downgraded to ZOMBIE.");
  }

  final Completer<void> _sessionReady = Completer<void>();
  bool _sessionInitialized = false;

  Future<void> _ensureSessionInitialized() async {
    if (_sessionInitialized) return;
    _sessionInitialized = true;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Ensure proper Android attributes
      await _player.setAndroidAudioAttributes(const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ));
      DebugLogService().info("NativeMusicService: Audio Session Configured");
    } catch (e) {
      DebugLogService().error("NativeMusicService: Session Init Error: $e");
    }
    if (!_sessionReady.isCompleted) _sessionReady.complete();
  }

  // Side-Car Handler
  MusicHandler? _audioHandler;
  MusicHandler? get audioHandler => _audioHandler;
  final Completer<void> _audioHandlerReady = Completer<void>();

  Future<void> _initAudioHandler() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => MusicHandler(playbackEventStream), // 🚀 Dynamic stream provider
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.simplemusicplayer.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      );

      // 🚀 ERROR & STATE LOGGING
      // 🚀 Listeners moved to _setupListeners called in constructor for all platforms

      // Register pending callbacks if any
      if (_onNext != null) _audioHandler!.onSkipNext = _onNext;
      if (_onPrev != null) _audioHandler!.onSkipPrevious = _onPrev;

      DebugLogService().info("NativeMusicService: AudioHandler Initialized");
      _audioHandlerReady.complete();
    } catch (e) {
      DebugLogService()
          .error("NativeMusicService: Failed to init AudioHandler: $e");
      _audioHandlerReady.complete(); // Complete anyway to unblock waiters
    }
  }

  // Callbacks
  VoidCallback? _onNext;
  VoidCallback? _onPrev;

  void setNotificationCallbacks({VoidCallback? onNext, VoidCallback? onPrev}) {
    _onNext = onNext;
    _onPrev = onPrev;
    if (_audioHandler != null) {
      _audioHandler!.onSkipNext = onNext;
      _audioHandler!.onSkipPrevious = onPrev;
    }
  }

// ... (skipping unchanged parts)

  Future<void> resume() async {
    if (_isZombie) return;
    final positionBefore = _player.position;
    // final sourceBefore = _player.sequenceState?.currentSource?.tag;
    DebugLogService().info(
        "[Native] resume() called. ServiceHash=${this.hashCode}, PlayerHash=${_player.hashCode}, Pos=${positionBefore.inSeconds}s");

    // 3. PLAY.
    // 🚀 FIX: Removed aggressive stop() on Android which caused playback failures.
    if (Platform.isAndroid) {
      await _player.seek(positionBefore);
    }

    // 🚀 NON-BLOCKING: Do not await play()!
    // Protective catch to prevent crash if player was disposed or failed hardware init
    _player.play().catchError((e) {
      DebugLogService().error("[Native] play() FAILED: $e");
    });
    final positionAfter = _player.position;
    DebugLogService()
        .info("[Native] resume() DONE. Pos=${positionAfter.inSeconds}s");
  }

  AudioPlayer _player1 = AudioPlayer();
  AudioPlayer _player2 = AudioPlayer();
  int _activePlayerIndex = 1; // 1 or 2
  Timer? _fadeTimer;
  double _currentVolume = 0.5; // 🚀 TRACK CURRENT VOLUME

  AudioPlayer get _player => _activePlayerIndex == 1 ? _player1 : _player2;
  AudioPlayer get _inactivePlayer => _activePlayerIndex == 1 ? _player2 : _player1;
  AudioPlayer get player => _player; // Interface for external listeners

  // 🚀 DYNAMIC STREAMS For UI Synchronization during Crossfade
  Stream<Duration> get positionStream => _activePlayerSubject.switchMap((p) => p.positionStream);
  Stream<Duration?> get durationStream => _activePlayerSubject.switchMap((p) => p.durationStream);
  Stream<PlayerState> get playerStateStream => _activePlayerSubject.switchMap((p) => p.playerStateStream);
  Stream<PlaybackEvent> get playbackEventStream => _activePlayerSubject.switchMap((p) => p.playbackEventStream);

  Future<void> load(SongModel song,
      {Duration? initialPosition, bool lazyLoad = false}) async {
    // 🚀 ALLOW LOAD IN ZOMBIE STATE
    // We must allow the player to prepare the source even if we aren't the primary audio focus yet.
    // This allows the UI to show the correct duration and be ready to play on user input.
    /*
    if (_isZombie) {
      DebugLogService().info("[Native] load() BLOCKED (Zombie)");
      return;
    }
    */
    try {
      // 🚀 UPDATE METADATA (Mobile Only) - CALL BEFORE LOADING
      // This ensures title/artist updates BEFORE the player fires 'buffering' events.
      if (Platform.isAndroid || Platform.isIOS) {
        await _updateAudioServiceMetadata(song);
      }
      DebugLogService().info(
          "[Native] load() called. ServiceHash=${this.hashCode}, PlayerHash=${_player.hashCode}");
      DebugLogService().info("[Native] load() called for: ${song.title}");
      debugPrint("🎵 Service Pre-Loading: ${song.title}");
      debugPrint("🎵 File Path: ${song.filePath}");

      // 🚀 RELOAD GUARD: Prevent re-initializing the same song (Fixes 0:00 reset and potentially ghost audio)
      final currentSource = _player.sequenceState?.currentSource;
      if (currentSource != null) {
        final currentTag = currentSource.tag as SongModel?;
        if (currentTag == song) {
          DebugLogService().info(
              "[Native] load() SKIPPED - Song already loaded: ${song.title}");
          return;
        }
      }
      if (song.filePath == "cloud_stream") {
        debugPrint(
            "☁️ Pre-Resolving Cloud Stream: ${song.title} - ${song.artist}");

        try {
          final yt = YoutubeExplode();
          String? targetId;

          // 🚀 PRIORITY: Use valid sourceUrl if available (passed from JIT fallback)
          if (song.sourceUrl != null &&
              song.sourceUrl!.isNotEmpty &&
              !song.sourceUrl!.startsWith('query:')) {
            final videoId = VideoId.parseVideoId(song.sourceUrl!);
            if (videoId != null) {
              targetId = videoId;
              debugPrint("✅ Using Source URL (Load): $targetId");
            }
          }

          if (targetId == null) {
            // Fallback to Search
            final query = "${song.title} ${song.artist} audio";
            final search = await yt.search.search(query);
            if (search.isNotEmpty) {
              targetId = search.first.id.value;
              debugPrint(
                  "✅ Found Video via Search (Load): ${search.first.title} ($targetId)");
            }
          }

          if (targetId != null) {
            final manifest =
                await yt.videos.streamsClient.getManifest(targetId);
            final audioInfo = manifest.audioOnly.withHighestBitrate();

            // 🚀 REMOVED explicit _player.stop() to prevent "Loading interrupted" race conditions.
            // setAudioSource already handles stopping the previous source.

            try {
              await _player.setAudioSource(
                AudioSource.uri(
                  audioInfo.url,
                  tag: song,
                ),
                initialPosition: initialPosition,
              );
              debugPrint("🎵 Pre-Load Cloud Stream Success");
            } catch (e) {
              debugPrint("⚠️ Pre-Load Interrupted/Failed: $e");
              debugPrint("🚀 Retrying with preload=false (Lazy Load)...");
              // Fallback: Lazy load. Sets the source but postpones buffering until play() is called.
              // This ensures the player is NOT empty/stuck.
              await _player.setAudioSource(
                AudioSource.uri(
                  audioInfo.url,
                  tag: song,
                ),
                initialPosition: initialPosition,
                preload: false,
              );
              debugPrint("✅ Lazy Load Source Set.");
            }
            yt.close();
            return;
          }
          yt.close();
        } catch (e) {
          debugPrint("❌ Cloud Stream Pre-Load Error: $e");
        }
        return;
      }

      // Check if file exists
      final file = File(song.filePath);
      if (!await file.exists()) {
        debugPrint(
            "❌ Service Load Error: File does not exist at ${song.filePath}");
        return;
      }

      // 🚀 FLAC INTEGRITY CHECK
      if (song.filePath.toLowerCase().endsWith('.flac')) {
        if (!await FlacDownloaderService.isFlacFileValid(song.filePath)) {
          debugPrint(
              "❌ Service Load Error: Invalid FLAC file at ${song.filePath}");
          DebugLogService().error("Invalid FLAC header detected: ${song.title}");
          return;
        }
      }

      // 🚀 Optimization: Determine target player for preloading
      final p = lazyLoad ? _inactivePlayer : _player;
      
      // Use Uri.parse for better cross-platform compatibility
      final uri = Uri.file(song.filePath);
      debugPrint("🎵 URI: $uri");

      // 🚀 Update preloaded tracking for crossfade consumption
      if (lazyLoad) {
        _preloadedFilePath = song.filePath;
        _preloadedSong = song;
      }

      await p.setAudioSource(
        AudioSource.uri(
          uri,
          tag: song,
        ),
        initialPosition: initialPosition,
        preload: true, // 🚀 Set to true to actually buffer the next song
      );
      debugPrint("🎵 Pre-Load Success (${lazyLoad ? 'Inactive' : 'Active'} Player)");
    } catch (e, stackTrace) {
      debugPrint("❌ Service Load Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
    }
  }

  // Cache for extracted album art to avoid re-extracting every time
  final Map<String, Uri> _cachedArtUris = {};

  Future<void> _updateAudioServiceMetadata(SongModel song) async {
    // Wait for AudioHandler to be ready before setting metadata
    await _audioHandlerReady.future;

    if (_audioHandler == null) return;

    // === FALLBACK METADATA ===
    // Ensure notification always shows something meaningful
    final displayTitle =
        (song.title.isNotEmpty && song.title != "Unknown Title")
            ? song.title
            : _extractFilename(song.filePath);
    final displayArtist =
        (song.artist.isNotEmpty && song.artist != "Unknown Artist")
            ? song.artist
            : "Unknown Artist";
    final displayAlbum =
        (song.album.isNotEmpty && song.album != "Unknown Album")
            ? song.album
            : "Unknown Album";

    // === ARTWORK RESOLUTION ===
    Uri? artUri;

    // Priority 1: Online art URL (from Spotify/streaming sources)
    if (song.onlineArtUrl != null && song.onlineArtUrl!.isNotEmpty) {
      artUri = Uri.parse(song.onlineArtUrl!);
      debugPrint(
          "🎵 [Notification] Using online art URL: ${song.onlineArtUrl}");
    }
    // Priority 2: Embedded album art bytes already in memory
    else if (song.albumArtBytes != null && song.albumArtBytes!.isNotEmpty) {
      artUri = await _getOrCacheEmbeddedArt(song);
    }
    // Priority 3: Extract embedded art from audio file (for library/downloaded songs)
    else if (song.filePath != "cloud_stream") {
      artUri = await _extractArtFromFile(song.filePath);
    }
    // Priority 4: No art - Android will use app icon as fallback

    final item = MediaItem(
      id: song.filePath,
      album: displayAlbum,
      title: displayTitle,
      artist: displayArtist,
      duration: Duration(seconds: song.duration.toInt()),
      artUri: artUri,
    );

    _audioHandler!.mediaItem.add(item);
    debugPrint(
        "🎵 [Notification] Metadata updated: $displayTitle - $displayArtist (Art: ${artUri != null ? 'Yes' : 'App Icon'})");
  }

  /// Extract filename from path as fallback title
  String _extractFilename(String filePath) {
    if (filePath == "cloud_stream") return "Streaming...";
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last;
      // Remove extension
      final dotIndex = name.lastIndexOf('.');
      return dotIndex > 0 ? name.substring(0, dotIndex) : name;
    } catch (e) {
      return "Unknown Title";
    }
  }

  /// Get cached art URI or extract embedded art to temp file
  Future<Uri?> _getOrCacheEmbeddedArt(SongModel song) async {
    // Use filePath as cache key
    final cacheKey = song.filePath;

    // Return cached URI if available
    if (_cachedArtUris.containsKey(cacheKey)) {
      final cachedUri = _cachedArtUris[cacheKey]!;
      // Verify file still exists
      if (await File(cachedUri.toFilePath()).exists()) {
        debugPrint("🎵 [Notification] Using cached embedded art");
        return cachedUri;
      } else {
        _cachedArtUris.remove(cacheKey);
      }
    }

    // Extract and save to temp file
    try {
      final tempDir = Directory.systemTemp;
      final artFileName = 'album_art_${song.filePath.hashCode}.jpg';
      final artFile = File('${tempDir.path}/$artFileName');

      await artFile.writeAsBytes(song.albumArtBytes!);
      final artUri = artFile.uri;

      // Cache for future use
      _cachedArtUris[cacheKey] = artUri;

      debugPrint(
          "🎵 [Notification] Extracted embedded art to: ${artFile.path}");
      return artUri;
    } catch (e) {
      debugPrint("⚠️ [Notification] Failed to extract embedded art: $e");
      return null;
    }
  }

  /// Extract album art directly from audio file (for library songs without preloaded bytes)
  Future<Uri?> _extractArtFromFile(String filePath) async {
    // Check cache first
    if (_cachedArtUris.containsKey(filePath)) {
      final cachedUri = _cachedArtUris[filePath]!;
      if (await File(cachedUri.toFilePath()).exists()) {
        debugPrint("🎵 [Notification] Using cached file art");
        return cachedUri;
      } else {
        _cachedArtUris.remove(filePath);
      }
    }

    // Try to extract from file
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint("⚠️ [Notification] File doesn't exist: $filePath");
        return null;
      }

      final metadata = await MetadataGod.readMetadata(file: filePath);
      final artBytes = metadata.picture?.data;

      if (artBytes == null || artBytes.isEmpty) {
        debugPrint("🎵 [Notification] No embedded art in file: $filePath");
        return null;
      }

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final artFileName = 'album_art_${filePath.hashCode}.jpg';
      final artFile = File('${tempDir.path}/$artFileName');

      await artFile.writeAsBytes(artBytes);
      final artUri = artFile.uri;

      // Cache for future use
      _cachedArtUris[filePath] = artUri;

      debugPrint(
          "🎵 [Notification] Extracted art from file to: ${artFile.path}");
      return artUri;
    } catch (e) {
      debugPrint("⚠️ [Notification] Failed to extract art from file: $e");
      return null;
    }
  }

  Future<bool> play(SongModel song, {double crossfadeDuration = 0.0}) async {
    if (_isZombie) {
      DebugLogService().info(
          "[Native] play() called in Zombie state. Attempting to claim Mutex...");
      _tryClaimMutex();
      if (_isZombie) {
        DebugLogService()
            .info("[Native] play() BLOCKED (Zombie) - Claim failed");
        return false;
      }
    }

    // 🚀 CROSSFADE LOGIC
    if (crossfadeDuration > 0.1 && _player.playing) {
      return _startCrossfade(song, crossfadeDuration);
    }

    // Normal play logic (stops current player)
    _fadeTimer?.cancel();
    _fadeTimer = null; // Clear timer reference
    try {
      _player.setVolume(_currentVolume); // 🚀 FIX: Use tracked volume instead of hardcoded 1.0
      _inactivePlayer.stop(); // Stop the inactive player to prepare it for next use
    } catch (e) {
      DebugLogService().error("Error during normal play setup: $e");
    }

    // 🚀 Loading Guard: Wait for any pending load to finish, then cancel it
    if (_isLoading && _loadingCompleter != null) {
      DebugLogService()
          .info("[Native] play() Waiting for previous load to finish...");
      // Stop previous load by stopping player
      await _player.stop();
      _isLoading = false;
      _loadingCompleter?.complete();
    }

    // Mark as loading
    _isLoading = true;
    _loadingCompleter = Completer<void>();

    try {
      DebugLogService().info(
          "[Native] play() called. ServiceHash=${this.hashCode}, PlayerHash=${_player.hashCode}");
      DebugLogService().info("[Native] play() called for: ${song.title}");
      debugPrint("🎵 Service Loading: ${song.title}");
      debugPrint("🎵 File Path: ${song.filePath}");

      // 🚀 UPDATE METADATA (Mobile Only) - Also update on play(), not just load()
      if (Platform.isAndroid || Platform.isIOS) {
        await _updateAudioServiceMetadata(song);
      }

      // STOP previous playback immediately (Fixes Ghost Song)
      // 🚀 FIX: Removed redundant stop() which caused buffer resets on Android.

      // 1. Check if file exists first
      // 1. CLOUD STREAM HANDLING (Party Mode)
      if (song.filePath == "cloud_stream") {
        debugPrint("☁️ Resolving Cloud Stream: ${song.title} - ${song.artist}");

        try {
          final yt = YoutubeExplode();
          // Sanitize query to remove newlines or weird chars
          final cleanTitle = song.title.replaceAll(RegExp(r'[\n\r]'), ' ');
          final cleanArtist = song.artist.replaceAll(RegExp(r'[\n\r]'), ' ');
          final query = "$cleanTitle $cleanArtist audio";

          final search = await yt.search.search(query);

          if (search.isNotEmpty) {
            final video = search.first;
            debugPrint("✅ Found Video: ${video.title} (${video.id})");

            final manifest =
                await yt.videos.streamsClient.getManifest(video.id);
            final audioInfo = manifest.audioOnly.withHighestBitrate();

            debugPrint("🎵 Stream URL: ${audioInfo.url}");

            // await _player.stop(); // 🚀 FIX: Same as below, removed for smoothness.
            await _player.setAudioSource(
              AudioSource.uri(
                audioInfo.url,
                tag: song,
              ),
            );
            // 🚀 NON-BLOCKING
            _player.play();
            yt.close();
            return true; // EXIT after starting stream
          } else {
            debugPrint("❌ No video found for cloud stream");
          }
          yt.close();
        } catch (e) {
          debugPrint("❌ Cloud Stream Error: $e");
          // Clear source so we don't hold onto the previous song
          try {
            await _player
                .setAudioSource(ConcatenatingAudioSource(children: []));
          } catch (_) {}
          return false;
        }
        return false; // Abort if cloud stream fails
      }

      // 2. FILE HANDLING (Original)
      final file = File(song.filePath);
      final exists = await file.exists();
      debugPrint("🎵 File exists: $exists");

      if (!exists) {
        debugPrint("❌ Service Error: File does not exist at ${song.filePath}");
        // Try to list parent directory to debug
        try {
          final parent = file.parent;
          if (await parent.exists()) {
            debugPrint("📂 Parent directory exists: ${parent.path}");
            final files = await parent.list().toList();
            debugPrint(
                "📂 Files in directory: ${files.map((f) => f.path.split('/').last).toList()}");
          } else {
            debugPrint("❌ Parent directory does not exist: ${parent.path}");
          }
        } catch (e) {
          debugPrint("❌ Error listing parent: $e");
        }
        return false;
      }

      final fileSize = await file.length();
      debugPrint("🎵 File size: ${fileSize} bytes");

      // 2. Stop previous playback explicitly to clear buffers
      // await _player.stop(); // 🚀 FIX: Removed redundant stop() to prioritize seamless transitions and prevent UI blink.

      // 3. Load the file using Uri.file for proper path handling
      final uri = Uri.file(song.filePath);
      debugPrint("🎵 Playing URI: $uri");

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: song,
        ),
      );
      debugPrint("🎵 Audio source set successfully");

      // 4. Force Play (Non-Blocking)
      _player.play();
      debugPrint("🎵 Play command sent");
      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ Service Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
      return false;
    } finally {
      // 🚀 Reset loading guard
      _isLoading = false;
      _loadingCompleter?.complete();
      _loadingCompleter = null;
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    DebugLogService().info("[Native] stop() called");
    await _player.stop();
  }

  Future<void> seek(double position) async {
    // 🚀 ALLOW SEEK (Initial position restore)
    await _player.seek(Duration(seconds: position.round()));
  }

  Future<void> setVolume(double volume) async {
    _currentVolume = volume;
    // Only apply immediately if not crossfading to avoid interrupting the fade
    if (_fadeTimer == null || !_fadeTimer!.isActive) {
      try {
        await _player1.setVolume(volume);
        await _player2.setVolume(volume);
      } catch (e) {
        // Silently ignore disposal errors during setVolume to prevent app crash
        // This can happen during late events on shutdown or hot restart
      }
    }
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player1.setLoopMode(mode);
    await _player2.setLoopMode(mode);
  }

  void _setupListeners(int index) {
    final p = index == 1 ? _player1 : _player2;
    p.playbackEventStream.listen((event) {}, onError: (e, s) {
      DebugLogService().error("NativeMusicService: Playback Event Error (P$index): $e");
    });
    
    p.playerStateStream.listen((state) {
      if (_activePlayerIndex == index) {
        DebugLogService().info("NativeMusicService: Player$index State [${state.processingState}, ${state.playing}]");
      }
    });
  }

  void recreateActivePlayer() {
    final idx = _activePlayerIndex;
    DebugLogService().info("NativeMusicService: Recreating active player $idx due to fatal error.");
    try {
      if (idx == 1) {
        _player1.dispose().catchError((e) => null);
        _player1 = AudioPlayer();
        _setupListeners(1);
        _player1.setVolume(_currentVolume);
        _activePlayerSubject.add(_player1);
      } else {
        _player2.dispose().catchError((e) => null);
        _player2 = AudioPlayer();
        _setupListeners(2);
        _player2.setVolume(_currentVolume);
        _activePlayerSubject.add(_player2);
      }
    } catch (e) {
       DebugLogService().error("NativeMusicService: Recreate failed: $e");
    }
  }



  Future<bool> _startCrossfade(SongModel song, double duration) async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    
    final outPlayer = _player;
    final inPlayer = _inactivePlayer;

    DebugLogService().info("[Native] Starting Crossfade: ${duration}s");

    try {
      // 🚀 Optimize: Don't await non-critical setup calls to start fade faster
      inPlayer.stop(); 
      inPlayer.setVolume(0.0);
      outPlayer.setVolume(_currentVolume);

      // Load source (Only if not already preloaded)
      if (song.filePath == "cloud_stream") {
        // Resolve online stream (simplified: reuse existing logic if possible, or skip crossfade for cloud for now)
        // For now, let's just return false to fallback to normal play if it's cloud
        DebugLogService().info("[Native] Crossfade not supported for cloud streams yet.");
        return false;
      } else {
        // 🚀 CRITICAL OPTIMIZATION: Check if already preloaded to avoid "cropping" delay
        if (_preloadedFilePath == song.filePath && _preloadedSong?.title == song.title) {
          DebugLogService().info("[Native] Crossfade: Using preloaded source for ${song.title}");
        } else {
           DebugLogService().info("[Native] Crossfade: Song not preloaded, loading now: ${song.title}");
           await inPlayer.setAudioSource(
            AudioSource.uri(Uri.file(song.filePath), tag: song),
            preload: true,
          );
        }
      }

      // Clear preloaded state now that we are using it
      _preloadedFilePath = null;
      _preloadedSong = null;

      // Start playing incoming
      inPlayer.play();

      // Switch active player index & broadcast new player to UI streams instantly
      _activePlayerIndex = _activePlayerIndex == 1 ? 2 : 1;
      _activePlayerSubject.add(_player); 

      // Update Audio Service metadata to new song (Fire and forget)
      if (Platform.isAndroid || Platform.isIOS) {
        _updateAudioServiceMetadata(song);
      }

      // Fading logic
      const steps = 20;
      final stepDuration = Duration(milliseconds: (duration * 1000 / steps).round());
      int currentStep = 0;

      _fadeTimer = Timer.periodic(stepDuration, (timer) {
        currentStep++;
        // 🚀 DYNAMIC SCALING: Use _currentVolume directly in each step
        // This ensures the fade remains smooth even if the user slides the volume during the crossfade.
        double outVol = _currentVolume * (1.0 - (currentStep / steps));
        double inVol = _currentVolume * (currentStep / steps);

        if (outVol < 0) outVol = 0;
        if (inVol > _currentVolume) inVol = _currentVolume;

        outPlayer.setVolume(outVol);
        inPlayer.setVolume(inVol);

        if (currentStep >= steps) {
          timer.cancel();
          outPlayer.stop();
          outPlayer.setVolume(_currentVolume); // Reset for next use
          DebugLogService().info("[Native] Crossfade Complete");
        }
      });

      return true;
    } catch (e) {
      DebugLogService().error("Crossfade Error: $e");
      return false;
    }
  }
}

class _NativeLifecycleObserver extends WidgetsBindingObserver {
  final NativeMusicService _service;
  _NativeLifecycleObserver(this._service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service._tryClaimMutex();
    } else if (state == AppLifecycleState.detached) {
      // App is being killed - full cleanup
      debugPrint("🎵 Lifecycle: App DETACHED - Stopping Players");
      _service._player1.stop();
      _service._player2.stop();
      // 🚀 DO NOT DISPOSE in singleton lifecycle observer.
      // It causes crashes if any late events (like volume sync) fire.
      // The OS will clean up process resources anyway.
      _service._audioHandler?.stop();
    }
  }
}
