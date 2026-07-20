import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'vps_scraper_service.dart';
import 'spotify_lyrics_service.dart';
import 'db_service.dart';
import 'pocketbase_service.dart';
import '../utils/request_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../env/env.dart';
import '../models/song_metadata.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';

class SpotifyService {
  // Primary credentials (reserved for Canvas, Recommendations, Playlist Import)
  static String get _clientIdPrimary => Env.spotifyClientId;
  static String get _clientSecretPrimary => Env.spotifyClientSecret;

  // Secondary credentials (for high-volume search operations)
  static String get _clientIdSecondary => Env.spotifyClientId2;
  static String get _clientSecretSecondary => Env.spotifyClientSecret2;

  // Dual token pools
  static String? _accessTokenPrimary;
  static DateTime? _tokenExpiryPrimary;
  static String? _accessTokenSecondary;
  static DateTime? _tokenExpirySecondary;

  // --- 1. AUTHENTICATION ---

  /// Get token for PRIMARY key (Canvas, Recommendations, Playlist Import)
  static Future<String?> _getAccessTokenPrimary() async {
    return _getAccessTokenInternal(
      clientId: _clientIdPrimary,
      clientSecret: _clientSecretPrimary,
      tokenRef: () => _accessTokenPrimary,
      expiryRef: () => _tokenExpiryPrimary,
      setToken: (t) => _accessTokenPrimary = t,
      setExpiry: (e) => _tokenExpiryPrimary = e,
      keyName: 'PRIMARY',
    );
  }

  /// Get token for SECONDARY key (Search, general operations)
  static Future<String?> _getAccessTokenSecondary() async {
    // If secondary credentials not configured, fall back to primary
    if (_clientIdSecondary.isEmpty || _clientSecretSecondary.isEmpty) {
      return _getAccessTokenPrimary();
    }
    return _getAccessTokenInternal(
      clientId: _clientIdSecondary,
      clientSecret: _clientSecretSecondary,
      tokenRef: () => _accessTokenSecondary,
      expiryRef: () => _tokenExpirySecondary,
      setToken: (t) => _accessTokenSecondary = t,
      setExpiry: (e) => _tokenExpirySecondary = e,
      keyName: 'SECONDARY',
    );
  }

  /// Internal token fetcher
  static Future<String?> _getAccessTokenInternal({
    required String clientId,
    required String clientSecret,
    required String? Function() tokenRef,
    required DateTime? Function() expiryRef,
    required void Function(String?) setToken,
    required void Function(DateTime?) setExpiry,
    required String keyName,
  }) async {
    if (clientId.isEmpty || clientSecret.isEmpty) {
      return null;
    }

    // Check cached token
    final token = tokenRef();
    final expiry = expiryRef();
    if (token != null && expiry != null && DateTime.now().isBefore(expiry)) {
      return token;
    }

    try {
      final bytes = utf8.encode("$clientId:$clientSecret");
      final base64Str = base64.encode(bytes);

      final response = await http.post(
        Uri.parse("https://accounts.spotify.com/api/token"),
        headers: {
          "Authorization": "Basic $base64Str",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"grant_type": "client_credentials"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setToken(data['access_token']);
        setExpiry(DateTime.now().add(Duration(seconds: data['expires_in'])));
        return data['access_token'];
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  /// Legacy compatibility - uses PRIMARY (CLIENT_ID_1) for general search operations
  static Future<String?> _getAccessToken() async {
    return _getAccessTokenPrimary();
  }

  /// Get token with fallback: tries preferred, falls back to other on 429
  static Future<String?> _getTokenWithFallback(
      {bool preferPrimary = false}) async {
    try {
      if (preferPrimary) {
        return await _getAccessTokenPrimary();
      } else {
        return await _getAccessTokenSecondary();
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        try {
          if (preferPrimary) {
            return await _getAccessTokenSecondary();
          } else {
            return await _getAccessTokenPrimary();
          }
        } catch (e2) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  // --- 2. GET ARTIST GENRES ---
  static final Map<String, String> _genreCache = {};

  static Future<String> getArtistGenres(String artistId) async {
    if (_genreCache.containsKey(artistId)) return _genreCache[artistId]!;

    final token = await _getAccessToken();
    if (token == null) return "";

    try {
      final uri = Uri.https('api.spotify.com', '/v1/artists/$artistId');
      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final genres = List<String>.from(data['genres'] ?? []);

        // Capitalize first letter for display
        if (genres.isNotEmpty) {
          String mainGenre = genres.first;
          mainGenre = mainGenre[0].toUpperCase() + mainGenre.substring(1);
          _genreCache[artistId] = mainGenre;
          return mainGenre;
        }
      }
    } catch (e) {
      //
    }
    return "";
  }

  /// Fallback Search Method for Metadata via Proxy
  static Future<List<Map<String, dynamic>>> searchMetadataViaProxy(String query) async {
    try {
      final baseUrl = Env.externalLyricsUrl;
      if (baseUrl.isEmpty) return [];

      final cleanQ = Uri.encodeComponent(query.trim());
      final searchUrl = Uri.parse('$baseUrl/spotify/search?q=$cleanQ');

      debugPrint("🔍 [Search Proxy] Executing fallback query for: ${query.trim()}");
      final res = await http.get(searchUrl).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];

      final decoded = json.decode(res.body);
      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        items = decoded['data'];
      }

      return items.map<Map<String, dynamic>>((item) {
        final title = (item['name'] ?? item['title'] ?? 'Unknown Title').toString();
        final artist = (item['artistName'] ?? item['artist'] ?? 'Unknown Artist').toString();
        final album = (item['albumName'] ?? item['album'] ?? 'Unknown Album').toString();
        final imageUrl = (item['albumCover'] ?? item['image_url'] ?? item['image'] ?? '').toString();
        final spotifyId = (item['trackId'] ?? item['id'] ?? '').toString();

        int durationMs = 0;
        if (item['duration_ms'] != null && item['duration_ms'] is int) {
          durationMs = item['duration_ms'] as int;
        } else if (item['duration'] != null && item['duration'] is String) {
          final parts = (item['duration'] as String).split(':');
          if (parts.length == 2) {
            durationMs = ((int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)) * 1000;
          }
        }

        return {
          'title': title,
          'artist': artist,
          'album': album,
          'year': '',
          'image_url': imageUrl,
          'spotify_id': spotifyId,
          'duration_ms': durationMs,
          'track_number': 1,
          'disc_number': 1,
          'artist_id': '',
          'isrc': item['isrc'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint("💥 Proxy Search Exception: $e");
      return [];
    }
  }

  // --- 3. SEARCH METADATA (Rich Data for Editor) ---
  static Future<List<Map<String, dynamic>>> searchMetadata(String query) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableOnlineSearch) {
      return []; // 🔒 OFFLINE or Online Search Disabled
    }

    try {
      final token = await _getTokenWithFallback(preferPrimary: true).catchError((_) => null);

      if (token != null) {
        final uri = Uri.https('api.spotify.com', '/v1/search', {
          'q': query,
          'type': 'track',
          'limit': '10',
        });

        final response =
            await http.get(uri, headers: {"Authorization": "Bearer $token"}).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['tracks']['items'] as List;

          return items.map((item) {
            final album = item['album'];
            final artistsList = (item['artists'] as List);
            final artists =
                artistsList.map((a) => a['name'].toString()).join(", ");

            final primaryArtistId =
                artistsList.isNotEmpty ? artistsList[0]['id'] : "";

            String? imageUrl;
            if ((album['images'] as List).isNotEmpty) {
              imageUrl = album['images'][0]['url'];
            }

            return {
              'title': item['name'],
              'artist': artists,
              'album': album['name'],
              'year': (album['release_date'] as String).split('-')[0],
              'image_url': imageUrl,
              'spotify_id': item['id'],
              'duration_ms': item['duration_ms'],
              'track_number': item['track_number'],
              'disc_number': item['disc_number'],
              'artist_id': primaryArtistId,
              'isrc': item['external_ids']?['isrc'],
            };
          }).toList();
        } else {
          debugPrint("⚠️ Spotify Metadata Search status ${response.statusCode}. Falling back to proxy search...");
        }
      } else {
        debugPrint("⚠️ Spotify token null/rate-limited. Falling back to proxy search...");
      }
    } catch (e) {
      debugPrint("⚠️ Spotify Metadata Search Error: $e. Falling back to proxy search...");
    }

    return await searchMetadataViaProxy(query);
  }

  // --- 3.5 SEARCH BY ISRC ---
  static Future<List<SongMetadata>> searchByIsrc(String isrc) async {
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      final query = "isrc:$isrc";

      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
        'market': 'US',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;

        if (items.isNotEmpty) {
          final item = items[0];
          final album = item['album'];
          final artistsList = (item['artists'] as List);
          final artistName =
              artistsList.isNotEmpty ? artistsList[0]['name'] : "Unknown";

          String imageUrl = "";
          if ((album['images'] as List).isNotEmpty) {
            imageUrl = album['images'][0]['url'];
          }

          return [
            SongMetadata(
              title: item['name'],
              artist: artistName,
              album: album['name'],
              year: (album['release_date'] as String).split('-')[0],
              genre: "Pop",
              trackNumber: item['track_number'],
              discNumber: item['disc_number'],
              durationSeconds: (item['duration_ms'] as int) ~/ 1000,
              albumArtUrl: imageUrl,
              isrc: item['external_ids']?['isrc'],
            )
          ];
        }
      }
    } catch (e) {
      //
    }
    return [];
  }

  // --- 4. SMART DOWNLOAD SEARCH METHOD (New) ---
  static Future<List<SongMetadata>> searchTracks(String query) async {
    final rawResults = await searchMetadata(query);

    final futures = rawResults.map((item) async {
      final String artist = item['artist'] as String;
      final String title = item['title'] as String;
      final int durationMs = item['duration_ms'] as int;
      final String imageUrl = item['image_url'] as String? ?? '';
      final String album = item['album'] as String? ?? 'Unknown Album';
      final String year = item['year'] as String? ?? '';
      final int? trackNum = item['track_number'] as int?;
      final int? discNum = item['disc_number'] as int?;
      final String? isrc = item['isrc'] as String?;
      final String? spotifyId = item['spotify_id'] as String?;
      String genre = "Pop";
      final String artistId = item['artist_id'] as String? ?? "";
      if (artistId.isNotEmpty) {
        genre = await getArtistGenres(artistId);
      }

      return SongMetadata(
        title: title,
        artist: artist,
        album: album,
        year: year,
        genre: genre,
        trackNumber: trackNum,
        discNumber: discNum,
        durationSeconds: durationMs ~/ 1000,
        albumArtUrl: imageUrl,
        isrc: isrc,
        spotifyId: spotifyId,
      );
    });

    return Future.wait(futures);
  }

  // --- 5. GET ARTIST ID ---
  static Future<String?> _getArtistIdWithToken(
      String token, String artistName, String? trackTitle) async {
    String? spotifyArtistId;
    final cleanArtist = _cleanTerm(artistName);
    final cleanTrack = trackTitle != null ? _cleanTerm(trackTitle) : "";

    if (cleanTrack.isNotEmpty) {
      spotifyArtistId =
          await _findArtistIdByTrack(token, cleanArtist, cleanTrack);
    }
    spotifyArtistId ??= await _findArtistIdByName(token, cleanArtist);
    return spotifyArtistId;
  }

  static Future<String?> getArtistId({
    required String artistName,
    String? trackTitle,
    bool preferPrimary = true,
  }) async {
    // 1. Try Primary Token Flow
    try {
      final token = await _getTokenWithFallback(preferPrimary: preferPrimary);
      if (token != null) {
        final id = await _getArtistIdWithToken(token, artistName, trackTitle);
        if (id != null) return id;
      }
    } catch (e) {
      debugPrint("⚠️ Spotify Primary Search failed: $e. Falling back to Secondary...");
    }

    // 2. Try Secondary Token Flow as Fallback
    try {
      final altToken = await _getTokenWithFallback(preferPrimary: !preferPrimary);
      if (altToken != null) {
        final id = await _getArtistIdWithToken(altToken, artistName, trackTitle);
        if (id != null) return id;
      }
    } catch (e) {
      debugPrint("⚠️ Spotify Secondary Search failed: $e");
    }

    return null;
  }

  // --- 6. GET FRESH BANNER URL (Custom Backend) ---
  static Future<String?> getFreshBannerUrl(String artistId) async {
    try {
      final String baseUrl = Env.spotifyBannerUrl;
      if (baseUrl.isNotEmpty) {
        final uri = Uri.parse("$baseUrl/api/extractbanner");
        final String fullSpotifyUrl = "https://open.spotify.com/artist/$artistId";

        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"artistUrl": fullSpotifyUrl, "deviceType": "desktop"}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = jsonDecode(response.body);

          if (json['success'] == true && json['data'] != null) {
            final data = json['data'];
            String? banner = data['bannerUrl'];

            if (banner == null && data['imagePath'] != null) {
              banner = "$baseUrl${data['imagePath']}";
            }

            if (banner != null && banner.isNotEmpty) {
              return banner;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ getFreshBannerUrl backend error: $e");
    }

    try {
      final scrapeUrl = Uri.parse("https://open.spotify.com/artist/$artistId");
      final response = await http.get(scrapeUrl, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        final html = response.body;

        final RegExp regex =
            RegExp(r'"header_image":\s*\{\s*"image":\s*"(https:[^"]+)"');
        final match = regex.firstMatch(html);

        if (match != null) {
          String? url = match.group(1);
          url = url?.replaceAll(r'\/', '/');
          if (url != null) {
            return url;
          }
        }

        final RegExp ogRegex =
            RegExp(r'<meta property="og:image" content="(https:[^"]+)"');
        final ogMatch = ogRegex.firstMatch(html);
        if (ogMatch != null) {
          return ogMatch.group(1);
        }
      }
    } catch (e) {
      //
    }

    return null;
  }

  // --- 7. GET STANDARD ARTIST IMAGE ---
  static Future<String?> getArtistImage({
    required String artistName,
    String? trackTitle,
    bool highQuality = false,
    bool preferPrimary = true,
  }) async {
    final cacheKey = "profile:$artistName"; // Unified Key

    // STEP 0: Check Database Cache (Instant, Offline)
    try {
      final cachedUrl = await DBService().getArtCache(cacheKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        debugPrint("💾 [CACHE] Artist Profile: $artistName");
        return cachedUrl;
      }
    } catch (e) {
      debugPrint("⚠️ DB Cache read failed: $e");
    }

    String? foundArtistId;

    // STEP 1: Try official Spotify API first (Fastest)
    try {
      final token = await _getTokenWithFallback(preferPrimary: preferPrimary);
      if (token != null) {
        foundArtistId = await getArtistId(
            artistName: artistName,
            trackTitle: trackTitle,
            preferPrimary: preferPrimary);

        if (foundArtistId != null) {
          final spotifyImage =
              await _fetchImageByArtistId(token, foundArtistId, highQuality);
          if (spotifyImage != null && spotifyImage.isNotEmpty) {
            debugPrint(
                "⚡ [SPOTIFY] Artist: $artistName (Key: ${preferPrimary ? 'PRIMARY' : 'SECONDARY'})");
            // Save to Cache
            DBService().saveArtCache(cacheKey, spotifyImage);
            return spotifyImage;
          }
        }
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        debugPrint(
            "🛑 [SPOTIFY] Key ${preferPrimary ? 'PRIMARY' : 'SECONDARY'} blocked, trying backup...");
        // RETRY ONCE with the opposite key
        try {
          final tokenBackup =
              await _getTokenWithFallback(preferPrimary: !preferPrimary);
          if (tokenBackup != null) {
            foundArtistId = await getArtistId(
                artistName: artistName,
                trackTitle: trackTitle,
                preferPrimary: !preferPrimary);

            if (foundArtistId != null) {
              final spotifyImage = await _fetchImageByArtistId(
                  tokenBackup, foundArtistId, highQuality);
              if (spotifyImage != null && spotifyImage.isNotEmpty) {
                debugPrint(
                    "⚡ [SPOTIFY] Artist: $artistName (Key: ${!preferPrimary ? 'PRIMARY' : 'SECONDARY'} - BACKUP)");
                DBService().saveArtCache(cacheKey, spotifyImage);
                return spotifyImage;
              }
            }
          }
        } catch (_) {}
      }
    }

    // STEP 2: Fallback to VPS Scraper (Keyless, handles Rate Limits)
    try {
      debugPrint("🛰️ [VPS] Fetching: $artistName...");
      // Pass the ID if we found it, so the VPS doesn't have to search!
      final vpsImage = await imageRequestQueue.add(() =>
          VpsScraperService.getArtistImage(artistName,
              artistId: foundArtistId));
      if (vpsImage != null && vpsImage.isNotEmpty) {
        debugPrint("✅ [VPS] Success: $artistName");
        // Save to Cache
        DBService().saveArtCache(cacheKey, vpsImage);
        return vpsImage;
      }
    } catch (e) {
      debugPrint("❌ [VPS] Failed: $artistName - $e");
    }

    return null;
  }

  // --- 8. GET TRACK IMAGE & LINK ---

  static Future<String?> getTrackLink(String title, String artist,
      {bool preferPrimary = true, bool fallbackToProxy = false}) async {
    try {
      final token = await _getTokenWithFallback(preferPrimary: preferPrimary);
      if (token == null) {
        if (fallbackToProxy) {
          return await _getProxyTrackLinkFallback(title, artist);
        }
        return null;
      }

      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);
      final query = "track:$cleanTitle artist:$cleanArtist";

      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          final link = items[0]['external_urls']['spotify'];
          return link;
        }
      } else if (response.statusCode == 429) {
        debugPrint(
            "⚠️ getTrackLink: API returned 429${fallbackToProxy ? ', trying proxy...' : ''}");
        if (fallbackToProxy) {
          return await _getProxyTrackLinkFallback(title, artist);
        }
        throw Exception("rate_limit_429");
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        // Spotify server outage — suppress spam, just log once quietly
      } else {
        debugPrint("❌ Spotify getTrackLink: Failed. Status: ${response.statusCode}");
        debugPrint("Response: ${response.body}");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        rethrow;
      }
      debugPrint("⚠️ Spotify getTrackLink error: $e${fallbackToProxy ? ', trying proxy...' : ''}");
      if (fallbackToProxy) {
        return await _getProxyTrackLinkFallback(title, artist);
      }
    }
    if (fallbackToProxy) {
      return await _getProxyTrackLinkFallback(title, artist);
    }
    return null;
  }

  static Future<String?> getTrackImage(String title, String artist,
      {bool preferPrimary = true, bool fallbackToProxy = false}) async {
    final cacheKey = "track:$artist-$title";

    // STEP 0: Check Database Cache
    try {
      final cachedUrl = await DBService().getArtCache(cacheKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        return cachedUrl;
      }
    } catch (e) {
      debugPrint("⚠️ DB Cache read failed (track): $e");
    }

    try {
      final token = await _getTokenWithFallback(preferPrimary: preferPrimary);
      if (token == null) {
        if (fallbackToProxy) {
          return await _getProxyTrackImageFallback(title, artist, cacheKey);
        }
        return null;
      }

      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);
      final query = "track:$cleanTitle artist:$cleanArtist";

      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          final track = items[0];
          final images = track['album']['images'] as List;
          if (images.isNotEmpty) {
            final url = images[0]['url'];
            // Save to Cache
            DBService().saveArtCache(cacheKey, url);
            return url;
          }
        }
      } else if (response.statusCode == 429) {
        debugPrint("⚠️ getTrackImage: API returned 429${fallbackToProxy ? ', trying proxy...' : ''}");
        if (fallbackToProxy) {
          return await _getProxyTrackImageFallback(title, artist, cacheKey);
        }
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        if (fallbackToProxy) {
          return await _getProxyTrackImageFallback(title, artist, cacheKey);
        }
        rethrow;
      }
      debugPrint("⚠️ Spotify getTrackImage error: $e${fallbackToProxy ? ', trying proxy...' : ''}");
      if (fallbackToProxy) {
        return await _getProxyTrackImageFallback(title, artist, cacheKey);
      }
    }
    if (fallbackToProxy) {
      return await _getProxyTrackImageFallback(title, artist, cacheKey);
    }
    return null;
  }

  static Future<String?> _getProxyTrackLinkFallback(String title, String artist) async {
    try {
      debugPrint("🔄 [SpotifyService] Official API failed/limited, falling back to Proxy getTrackLink for: $title - $artist");
      final proxyLink = await SpotifyLyricsService.getTrackLink(title, artist);
      if (proxyLink != null) {
        debugPrint("✅ [SpotifyService] Successfully retrieved track link via proxy: $proxyLink");
        return proxyLink;
      }
    } catch (e) {
      debugPrint("❌ [SpotifyService] Proxy getTrackLink fallback failed: $e");
    }
    return null;
  }

  static Future<String?> _getProxyTrackImageFallback(String title, String artist, String cacheKey) async {
    try {
      debugPrint("🔄 [SpotifyService] Official API failed/limited, falling back to Proxy getTrackImage for: $title - $artist");
      final metadata = await SpotifyLyricsService.searchMetadataViaProxy(title, artist);
      if (metadata != null) {
        final url = metadata['image_url'] as String?;
        if (url != null && url.isNotEmpty) {
          DBService().saveArtCache(cacheKey, url);
          debugPrint("✅ [SpotifyService] Successfully retrieved track image via proxy: $url");
          return url;
        }
      }
    } catch (e) {
      debugPrint("❌ [SpotifyService] Proxy getTrackImage fallback failed: $e");
    }
    return null;
  }

  // --- 9. GET NEW RELEASES (Dynamic) ---
  static Future<List<Map<String, dynamic>>> getNewReleases(
      {String market = 'US'}) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableOnlineSearch) {
      return []; // 🔒 OFFLINE or Online Search Disabled
    }
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      // DYNAMIC QUERY
      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': 'year:${DateTime.now().year}', // Always current year
        'type': 'album',
        'limit': '10',
        'market': market,
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['albums']['items'] as List;

        debugPrint("✅ New Releases ($market): ${items.length} items");

        return items.map((item) {
          final images = item['images'] as List;
          return {
            'title': item['name'],
            'artist':
                (item['artists'] as List).map((a) => a['name']).join(", "),
            'image_url': images.isNotEmpty ? images[0]['url'] : '',
            'uri': item['uri'],
            'id': item['id'],
            'type': 'album',
          };
        }).toList();
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      debugPrint("New Releases Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  /// Fallback Search Method for searchAll via Proxy (Grouped Search for Remote / Listening Party)
  static Future<Map<String, dynamic>> searchAllViaProxy(String query,
      {int limit = 5}) async {
    final rawList = await searchMetadataViaProxy(query);
    final limited = rawList.take(limit).toList();

    final songs = limited.map((e) {
      return SongMetadata(
        title: e['title'] ?? 'Unknown Title',
        artist: e['artist'] ?? 'Unknown Artist',
        album: e['album'] ?? 'Unknown Album',
        year: e['year'] ?? '',
        genre: 'Pop',
        durationSeconds: ((e['duration_ms'] as int? ?? 0) ~/ 1000),
        albumArtUrl: e['image_url'] ?? '',
        isrc: e['isrc'],
        spotifyId: e['spotify_id'],
      );
    }).toList();

    // Extract unique albums from songs
    final albums = <AlbumModel>[];
    final seenAlbums = <String>{};
    for (var item in limited) {
      final albumName = item['album'] as String? ?? '';
      if (albumName.isNotEmpty && !seenAlbums.contains(albumName)) {
        seenAlbums.add(albumName);
        albums.add(AlbumModel(
          id: item['spotify_id'] ?? albumName,
          title: albumName,
          artist: item['artist'] ?? 'Unknown Artist',
          imageUrl: item['image_url'] ?? '',
          releaseDate: item['year'] ?? '',
        ));
      }
    }

    // Extract unique artists from songs
    final artists = <ArtistModel>[];
    final seenArtists = <String>{};
    for (var item in limited) {
      final artistName = item['artist'] as String? ?? '';
      if (artistName.isNotEmpty && !seenArtists.contains(artistName)) {
        seenArtists.add(artistName);
        artists.add(ArtistModel(
          id: item['artist_id'] ?? artistName,
          name: artistName,
          imageUrl: item['image_url'] ?? '',
        ));
      }
    }

    return {
      'songs': songs,
      'albums': albums,
      'artists': artists,
    };
  }

  static Future<List<AlbumModel>> searchAlbums(String query) async {
    try {
      final token = await _getAccessToken();
      if (token != null) {
        final url = Uri.parse(
            'https://api.spotify.com/v1/search?q=$query&type=album&limit=5');

        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List items = data['albums']['items'];
          return items.map((e) => AlbumModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("⚠️ Spotify searchAlbums Error: $e");
    }

    final paxRes = await searchAllViaProxy(query, limit: 5);
    return (paxRes['albums'] as List<AlbumModel>?) ?? [];
  }

  static Future<Map<String, dynamic>> searchAll(String query,
      {int limit = 5}) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableOnlineSearch) {
      return {
        'songs': [],
        'albums': [],
        'artists': []
      }; // 🔒 OFFLINE or Online Search Disabled
    }

    try {
      // Uses PRIMARY (CLIENT_ID_1) first for remote search, falls back to SECONDARY on 429
      final token = await _getTokenWithFallback(preferPrimary: true).catchError((_) => null);

      if (token != null) {
        // Correct URL for searching (uses $query)
        final url = Uri.parse(
            'https://api.spotify.com/v1/search?q=$query&type=track,album,artist&limit=$limit');

        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // 1. Parse Songs (Manually mapping to fix missing fields)
          final tracks = (data['tracks']['items'] as List).map((e) {
            String image = "";
            if (e['album'] != null && (e['album']['images'] as List).isNotEmpty) {
              image = e['album']['images'][0]['url'];
            }

            String artist = "Unknown";
            if ((e['artists'] as List).isNotEmpty) {
              artist = e['artists'][0]['name'];
            }

            String year = "2000";
            if (e['album'] != null && e['album']['release_date'] != null) {
              year = (e['album']['release_date'] as String).split('-').first;
            }

            return SongMetadata(
              title: e['name'] ?? "Unknown Title",
              artist: artist,
              albumArtUrl: image,
              album: e['album']?['name'] ?? "Unknown Album",
              year: year,
              durationSeconds: (e['duration_ms'] ?? 0) ~/ 1000,
              genre: "Pop",
              isrc: e['external_ids']?['isrc'],
              spotifyId: e['id'], // CAPTURE SPOTIFY ID
            );
          }).toList();

          // 2. Parse Albums
          final albums = (data['albums']['items'] as List)
              .map((e) => AlbumModel.fromJson(e))
              .toList();

          // 3. Parse Artists
          final artists = (data['artists']['items'] as List)
              .map((e) => ArtistModel.fromJson(e))
              .toList();

          return {
            'songs': tracks,
            'albums': albums,
            'artists': artists,
          };
        } else {
          debugPrint("⚠️ Spotify SearchAll status code ${response.statusCode}. Falling back to proxy search...");
        }
      } else {
        debugPrint("⚠️ Spotify SearchAll token null/rate-limited. Falling back to proxy search...");
      }
    } catch (e) {
      debugPrint("⚠️ Spotify SearchAll Exception: $e. Falling back to proxy search...");
    }

    return await searchAllViaProxy(query, limit: limit);
  }

  // Get tracks for a specific album
  static Future<List<SongMetadata>> getAlbumTracks(String albumId) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception("Spotify Auth Failed - No token available");
    }

    // 1. First fetch the simplified tracks to get IDs
    final url = Uri.parse(
        'https://api.spotify.com/v1/albums/$albumId/tracks?limit=50&market=US');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 429) throw Exception("rate_limit_429");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['items'];

      // 2. Extract IDs for Batch Lookup (Limit 50 per call)
      // Note: Album tracks endpoint returns 'simplified' objects which lack ISRC.
      // We must fetch the full track object.
      List<String> trackIds = [];
      for (var item in items) {
        trackIds.add(item['id']);
      }

      if (trackIds.isEmpty) return [];

      // 3. Batch Fetch Full Track Details (to get ISRC)
      final String idsParam = trackIds.join(',');
      final fullTracksUrl = Uri.https('api.spotify.com', '/v1/tracks', {
        'ids': idsParam,
        'market': 'US',
      });

      final fullResponse = await http.get(
        fullTracksUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (fullResponse.statusCode == 429) throw Exception("rate_limit_429");

      if (fullResponse.statusCode == 200) {
        final fullData = jsonDecode(fullResponse.body);
        final List fullItems = fullData['tracks'] ?? [];

        return fullItems.map<SongMetadata>((e) {
          final album = e['album'];
          // Get image from the full track's album object if available,
          // otherwise it might be null if the tracks endpoint was called without album context,
          // but /tracks?ids returns the album object usually.
          String imageUrl = "";
          if (album != null && (album['images'] as List).isNotEmpty) {
            imageUrl = album['images'][0]['url'];
          }

          return SongMetadata(
            title: e['name'],
            artist: (e['artists'] as List).isNotEmpty
                ? e['artists'][0]['name']
                : "Unknown",
            albumArtUrl: imageUrl,
            album: album?['name'] ?? "",
            year: album?['release_date']?.split('-')?.first,
            durationSeconds: (e['duration_ms'] ?? 0) ~/ 1000,
            genre: null, // Default to null instead of "Pop"
            trackNumber: e['track_number'],
            discNumber: e['disc_number'],
            isrc: e['external_ids']?['isrc'], // ✅ ISRC NOW CAPTURED
          );
        }).toList();
      } else {
        throw Exception(
            "Spotify Batch Tracks Failed: ${fullResponse.statusCode}");
      }
    } else {
      throw Exception("Spotify AlbumTracks Failed: ${response.statusCode}");
    }
  }

  // 9. FETCH ARTIST IMAGE TO ALBUM DETAIL PAGE
  static Future<String?> getArtistImagetoAlbum(String artistName) async {
    final token = await _getAccessToken(); // Use your existing token method
    if (token == null) return null;

    try {
      final query = Uri.encodeComponent(artistName);
      // Search for the artist
      final uri = Uri.parse(
          'https://api.spotify.com/v1/search?q=$query&type=artist&limit=1');

      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['artists']['items'] as List;
        if (items.isNotEmpty) {
          final images = items[0]['images'] as List;
          if (images.isNotEmpty) {
            return images[0]['url'];
          }
        }
      }
    } catch (e) {
      // debugPrint("Error fetching artist image: $e");
    }
    return null;
  }

  // --- 10. GET ARTIST TOP TRACKS (New) ---
  static Future<List<SongMetadata>> getArtistTopTracks(String artistId) async {
    final token = await _getTokenWithFallback();
    if (token == null) return [];

    try {
      final uri = Uri.https('api.spotify.com',
          '/v1/artists/$artistId/top-tracks', {'market': 'US'});
      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks'] as List;

        return items.map((e) {
          final album = e['album'];
          final images = album['images'] as List;
          final imageUrl = images.isNotEmpty ? images[0]['url'] : "";

          return SongMetadata(
            title: e['name'],
            artist: (e['artists'] as List).isNotEmpty
                ? e['artists'][0]['name']
                : "Unknown",
            albumArtUrl: imageUrl,
            album: album['name'],
            year: (album['release_date'] as String).split('-').first,
            durationSeconds: (e['duration_ms'] ?? 0) ~/ 1000,
            genre: "Pop", // Default, hard to get per track efficiently
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Top Tracks Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  // --- 11. GET ARTIST ALBUMS (Discography) ---
  static Future<List<AlbumModel>> getArtistAlbums(String artistId) async {
    final token = await _getTokenWithFallback();
    if (token == null) return [];

    try {
      // Fetch albums and singles (to include EPs)
      final uri = Uri.https('api.spotify.com', '/v1/artists/$artistId/albums', {
        'include_groups': 'album,single', // Include singles for EPs
        'market': 'US',
        'limit': '50',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        // Use a Set to filter duplicates based on name (Spotify often returns duplicates)
        final seenNames = <String>{};
        final uniqueAlbums = <AlbumModel>[];

        for (var item in items) {
          final name = item['name'] as String;
          final type = item['album_type'] as String;
          final totalTracks = item['total_tracks'] as int;

          // Filter out 1-track singles to keep "Albums" view clean, but keep EPs
          if (type == 'single' && totalTracks < 2) continue;

          // Simple duplicate check
          if (!seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            uniqueAlbums.add(AlbumModel.fromJson(item));
          }
        }
        return uniqueAlbums;
      }
    } catch (e) {
      debugPrint("Artist Albums Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  // --- 12. GET SPOTIFY PLAYLIST TRACKS ---
  /// Fetches all tracks from a Spotify playlist, with pagination support for large playlists
  /// Returns a tuple of (playlist name, cover image, tracks)
  // 🔑 CRITICAL: Uses SECONDARY key (CLIENT_ID_2) for Playlist Import
  static Future<Map<String, dynamic>?> getPlaylistInfo(
      String playlistId) async {
    final token = await _getAccessTokenSecondary();
    if (token == null) return null;

    try {
      final uri = Uri.https('api.spotify.com', '/v1/playlists/$playlistId', {
        'fields': 'name,images,description,owner(display_name)',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['images'] as List;
        return {
          'name': data['name'],
          'description': data['description'],
          'owner': data['owner']?['display_name'],
          'image': images.isNotEmpty ? images[0]['url'] : null,
        };
      }
    } catch (e) {
      debugPrint("Playlist Info Error: $e");
    }
    return null;
  }

  /// Fetches all tracks from a Spotify playlist (handles pagination for 100+ tracks)
  // 🔑 CRITICAL: Uses SECONDARY key (CLIENT_ID_2) for Playlist Import
  static Future<List<SongMetadata>> getPlaylistTracks(String playlistId) async {
    final token = await _getAccessTokenSecondary();
    if (token == null) return [];

    List<SongMetadata> allTracks = [];
    String? nextUrl =
        'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=50&market=US';

    try {
      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode != 200) break;

        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        // Extract track IDs for batch lookup (to get ISRC)
        List<String> trackIds = [];
        for (var item in items) {
          final track = item['track'];
          if (track != null && track['id'] != null) {
            trackIds.add(track['id']);
          }
        }

        if (trackIds.isNotEmpty) {
          // Batch fetch full track details (to get ISRC)
          final String idsParam = trackIds.join(',');
          final fullTracksUrl = Uri.https('api.spotify.com', '/v1/tracks', {
            'ids': idsParam,
            'market': 'US',
          });

          final fullResponse = await http.get(
            fullTracksUrl,
            headers: {'Authorization': 'Bearer $token'},
          );

          if (fullResponse.statusCode == 200) {
            final fullData = jsonDecode(fullResponse.body);
            final List fullItems = fullData['tracks'];

            for (var e in fullItems) {
              if (e == null) continue;

              final album = e['album'];
              String imageUrl = "";
              if (album != null && (album['images'] as List).isNotEmpty) {
                imageUrl = album['images'][0]['url'];
              }

              allTracks.add(SongMetadata(
                title: e['name'] ?? "Unknown",
                artist: (e['artists'] as List).isNotEmpty
                    ? e['artists'][0]['name']
                    : "Unknown",
                albumArtUrl: imageUrl,
                album: album?['name'] ?? "",
                year: album?['release_date']?.split('-')?.first,
                durationSeconds: (e['duration_ms'] ?? 0) ~/ 1000,
                genre: null,
                trackNumber: e['track_number'],
                discNumber: e['disc_number'],
                isrc: e['external_ids']?['isrc'],
              ));
            }
          }
        }

        // Get next page URL (pagination)
        nextUrl = data['next'];

        // Rate limiting protection
        if (nextUrl != null) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      debugPrint("✅ Fetched ${allTracks.length} tracks from playlist");
      return allTracks;
    } catch (e) {
      debugPrint("Playlist Tracks Error: $e");
    }
    return allTracks;
  }

  /// Extracts playlist ID from a Spotify URL
  /// Supports: https://open.spotify.com/playlist/xxxxx or spotify:playlist:xxxxx
  static String? extractPlaylistId(String url) {
    // Handle spotify:playlist:ID format
    if (url.startsWith('spotify:playlist:')) {
      return url.split(':').last;
    }

    // Handle https://open.spotify.com/playlist/ID?... format
    final regex = RegExp(r'playlist[/:]([a-zA-Z0-9]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  // --- 13. GET RECOMMENDATIONS (Endless Queue) ---
  /// Fetches recommended tracks from Spotify API based on seed tracks, artists, or genres
  /// Used for the Endless Queue feature to auto-add similar songs
  // 🔑 CRITICAL: Uses SECONDARY key (CLIENT_ID_2) for Recommendations/Endless Queue
  static Future<List<SongMetadata>> getRecommendations({
    List<String>? seedTracks,
    List<String>? seedArtists,
    List<String>? seedGenres,
    int limit = 20,
    bool verbose = false,
  }) async {
    final token = await _getAccessTokenSecondary();
    if (token == null) {
      if (verbose) debugPrint("⚠️ getRecommendations: No access token");
      return [];
    }

    try {
      // Build query params - Spotify requires at least 1 seed and max 5 total seeds
      final params = <String, String>{
        'limit': limit.toString(),
        'market': 'US',
      };

      int seedCount = 0;

      if (seedTracks != null && seedTracks.isNotEmpty) {
        // Take up to 5 seed tracks (max combined seeds is 5)
        final tracks = seedTracks.take(5 - seedCount).toList();
        params['seed_tracks'] = tracks.join(',');
        seedCount += tracks.length;
        if (verbose) {
          debugPrint(
              "🌱 getRecommendations: Using seed_tracks: ${tracks.join(',')}");
        }
      }

      if (seedArtists != null && seedArtists.isNotEmpty && seedCount < 5) {
        final artists = seedArtists.take(5 - seedCount).toList();
        params['seed_artists'] = artists.join(',');
        seedCount += artists.length;
        if (verbose) {
          debugPrint(
              "🌱 getRecommendations: Using seed_artists: ${artists.join(',')}");
        }
      }

      if (seedGenres != null && seedGenres.isNotEmpty && seedCount < 5) {
        final genres = seedGenres.take(5 - seedCount).toList();
        params['seed_genres'] = genres.join(',');
        if (verbose) {
          debugPrint(
              "🌱 getRecommendations: Using seed_genres: ${genres.join(',')}");
        }
      }

      // Must have at least 1 seed
      if (seedCount == 0 && (seedGenres == null || seedGenres.isEmpty)) {
        if (verbose) debugPrint("⚠️ getRecommendations: No seeds provided");
        return [];
      }

      final uri = Uri.https('api.spotify.com', '/v1/recommendations', params);
      if (verbose) debugPrint("🔗 getRecommendations: Calling URL: $uri");

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (verbose) {
        debugPrint("📡 getRecommendations: Response status: ${response.statusCode}");
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks'] as List;

        if (verbose) debugPrint("✅ Fetched ${tracks.length} recommendations");

        return tracks.map((track) {
          final album = track['album'];
          final images = album['images'] as List;
          final imageUrl = images.isNotEmpty ? images[0]['url'] : "";

          final artists = track['artists'] as List;
          final artistName =
              artists.isNotEmpty ? artists[0]['name'] : "Unknown";
          final artistId = artists.isNotEmpty ? artists[0]['id'] : null;

          return SongMetadata(
            title: track['name'],
            artist: artistName,
            album: album['name'],
            albumArtUrl: imageUrl,
            year: (album['release_date'] as String?)?.split('-').first,
            durationSeconds: (track['duration_ms'] as int) ~/ 1000,
            genre: "Pop", // Default, would need extra API call for genre
            spotifyId: track['id'],
            isrc: track['external_ids']?['isrc'],
            spotifyArtistId: artistId,
          );
        }).toList();
      } else {
        if (verbose) {
          debugPrint("❌ Recommendations API Error: ${response.statusCode}");
          debugPrint("   Response body: ${response.body}");
        }

        // If 404, maybe the recommendations endpoint isn't available
        // Let's try a fallback to search-based similar tracks
        if (response.statusCode == 404 &&
            seedTracks != null &&
            seedTracks.isNotEmpty) {
          if (verbose) {
            debugPrint("🔄 Trying fallback: search for related tracks...");
          }
          return await _getRecommendationsFallback(seedTracks.first, limit,
              verbose: verbose);
        }
      }
    } catch (e, stack) {
      debugPrint("❌ Recommendations Error: $e");
      debugPrint("   Stack: $stack");
    }
    return [];
  }

  /// Fallback method using search to find similar tracks
  static Future<List<SongMetadata>> _getRecommendationsFallback(
      String seedTrackId, int limit,
      {bool verbose = false}) async {
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      // First, get the seed track info
      final trackUri = Uri.https('api.spotify.com', '/v1/tracks/$seedTrackId');
      final trackResponse = await http.get(
        trackUri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (trackResponse.statusCode != 200) {
        if (verbose) debugPrint("❌ Fallback: Could not get track info");
        return [];
      }

      final trackData = jsonDecode(trackResponse.body);
      // ignore: unused_local_variable
      final artistId = trackData['artists'][0]['id'];
      final artistName = trackData['artists'][0]['name'];

      if (verbose) {
        debugPrint("🔄 Fallback: Searching for more tracks by $artistName");
      }

      // Search for more tracks by this artist
      final searchUri = Uri.https('api.spotify.com', '/v1/search', {
        'q': 'artist:$artistName',
        'type': 'track',
        'limit': limit.toString(),
        'market': 'US',
      });

      final searchResponse = await http.get(
        searchUri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final tracks = searchData['tracks']['items'] as List;

        if (verbose) {
          debugPrint("✅ Fallback: Found ${tracks.length} tracks by $artistName");
        }

        return tracks.map((track) {
          final album = track['album'];
          final images = album['images'] as List;
          final imageUrl = images.isNotEmpty ? images[0]['url'] : "";

          final artists = track['artists'] as List;
          final trackArtistName =
              artists.isNotEmpty ? artists[0]['name'] : "Unknown";
          final trackArtistId = artists.isNotEmpty ? artists[0]['id'] : null;

          return SongMetadata(
            title: track['name'],
            artist: trackArtistName,
            album: album['name'],
            albumArtUrl: imageUrl,
            year: (album['release_date'] as String?)?.split('-').first,
            durationSeconds: (track['duration_ms'] as int) ~/ 1000,
            genre: "Pop",
            spotifyId: track['id'],
            isrc: track['external_ids']?['isrc'],
            spotifyArtistId: trackArtistId,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("❌ Fallback error: $e");
    }
    return [];
  }

  /// Get track ID from title and artist for use as seed
  static Future<String?> getTrackId(String title, String artist,
      {bool verbose = false}) async {
    final token = await _getAccessToken();
    if (token == null) {
      if (verbose) debugPrint("⚠️ getTrackId: No access token");
      return null;
    }

    try {
      // Try 1: Exact field search
      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);
      var query = "track:$cleanTitle artist:$cleanArtist";

      if (verbose) debugPrint("🔍 getTrackId: Trying exact search: $query");

      var uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });

      var response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          final id = items[0]['id'];
          if (verbose) debugPrint("✅ getTrackId: Found with exact search: $id");
          return id;
        }
      }

      // Try 2: Simple search (more lenient)
      query = "$cleanTitle $cleanArtist";
      if (verbose) debugPrint("🔍 getTrackId: Trying simple search: $query");

      uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '5',
      });

      response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          // Find best match
          for (final track in items) {
            final trackName = (track['name'] as String).toLowerCase();
            final trackArtists = (track['artists'] as List)
                .map((a) => (a['name'] as String).toLowerCase())
                .toList();

            if (trackName.contains(cleanTitle.toLowerCase()) &&
                trackArtists
                    .any((a) => a.contains(cleanArtist.toLowerCase()))) {
              final id = track['id'];
              // DebugLogService().info("✅ getTrackId: Found with simple search: $id");
              return id;
            }
          }
          // If no exact match, return first result
          final id = items[0]['id'];
          // if (verbose) debugPrint("✅ getTrackId: Using first result: $id");
          return id;
        }
      }

      if (verbose) {
        debugPrint("⚠️ getTrackId: No results found for '$title' by '$artist' via Official API. Trying proxy fallback...");
      }
    } catch (e) {
      debugPrint("❌ getTrackId Official API error: $e. Trying proxy fallback...");
    }

    // --- FALLBACK TO PAXSENIX PROXY ---
    try {
      final metadata = await searchMetadataViaProxy("$title $artist");
      if (metadata.isNotEmpty) {
        final id = metadata[0]['spotify_id'];
        if (id != null && id.toString().isNotEmpty) {
          if (verbose) debugPrint("✅ getTrackId: Found with proxy fallback: $id");
          return id.toString();
        }
      }
    } catch (e) {
      debugPrint("❌ getTrackId proxy fallback error: $e");
    }

    return null;
  }

  // --- PRIVATE HELPERS ---

  static Future<String?> _findArtistIdByTrack(
      String token, String cleanArtist, String cleanTitle) async {
    try {
      final query = "track:$cleanTitle artist:$cleanArtist";
      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          final track = items[0];
          final artists = track['artists'] as List;
          final match = artists.firstWhere(
            (a) => a['name']
                .toString()
                .toLowerCase()
                .contains(cleanArtist.toLowerCase()),
            orElse: () => artists[0],
          );
          return match['id'];
        }
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  static Future<String?> _findArtistIdByName(
      String token, String cleanName) async {
    try {
      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': cleanName,
        'type': 'artist',
        'limit': '10',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['artists']['items'] as List;
        if (items.isEmpty) return null;

        var bestMatch = items.firstWhere(
          (item) =>
              item['name'].toString().toLowerCase() == cleanName.toLowerCase(),
          orElse: () => items.first,
        );
        return bestMatch['id'];
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  // --- 8.5 GET BEST MATCH METADATA (For tagging) ---
  static Future<SongMetadata?> getBestMatchMetadata(
      String title, String artist) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      // Clean terms for better matching
      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);
      final query = "track:$cleanTitle artist:$cleanArtist";

      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;
        if (items.isNotEmpty) {
          final item = items[0];
          final album = item['album'];
          final artistsList = (item['artists'] as List);
          // Capitalize first letter of artist name
          final artistName =
              artistsList.isNotEmpty ? artistsList[0]['name'] : "Unknown";

          String imageUrl = "";
          if ((album['images'] as List).isNotEmpty) {
            imageUrl = album['images'][0]['url'];
          }

          // Fetch genre
          String genre = "Pop";
          final String artistId =
              artistsList.isNotEmpty ? artistsList[0]['id'] : "";
          if (artistId.isNotEmpty) {
            genre = await getArtistGenres(artistId);
          }

          return SongMetadata(
            title: item['name'],
            artist: artistName,
            album: album['name'],
            year: (album['release_date'] as String).split('-')[0],
            genre: genre,
            trackNumber: item['track_number'],
            discNumber: item['disc_number'],
            durationSeconds: (item['duration_ms'] as int) ~/ 1000,
            albumArtUrl: imageUrl,
            isrc: item['external_ids']?['isrc'],
          );
        }
      }
    } catch (e) {
      // debugPrint("Error fetching best match metadata: $e");
    }
    return null;
  }

  static Future<String?> _fetchImageByArtistId(
      String token, String artistId, bool highQuality) async {
    try {
      final uri = Uri.https('api.spotify.com', '/v1/artists/$artistId');
      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['images'] as List;
        if (images.isNotEmpty) {
          if (highQuality) return images[0]['url'];
          return images[images.length > 1 ? 1 : 0]['url'];
        }
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  static String _cleanTerm(String text) {
    if (text.isEmpty) return "";
    var cleaned = text.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s+(feat\.?|ft\.?|featuring|with|prod\.)\s+.*',
            caseSensitive: false),
        '');
    if (cleaned.contains(' x ')) cleaned = cleaned.split(' x ')[0];
    if (cleaned.contains(' X ')) cleaned = cleaned.split(' X ')[0];
    if (cleaned.contains(';')) cleaned = cleaned.split(';')[0];
    if (cleaned.contains(' / ')) cleaned = cleaned.split(' / ')[0];
    return cleaned.trim();
  }

  static String cleanTerm(String text) => _cleanTerm(text);
}

final spotifyArtistArtProvider =
    FutureProvider.family<String?, String>((ref, name) async {
  return await SpotifyService.getArtistImage(artistName: name);
});
