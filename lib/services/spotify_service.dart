import 'dart:convert';
import 'package:http/http.dart' as http;
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
      print("⚠️ Secondary Spotify credentials not configured, using primary");
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
      print("DEBUG: $keyName credentials empty!");
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

      print("🔑 Spotify Auth [$keyName]: Requesting new token...");
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
        print("✅ Spotify Auth [$keyName]: Token acquired");
        return data['access_token'];
      } else if (response.statusCode == 429) {
        print("❌ Spotify Auth [$keyName]: Rate Limit Exceeded");
        throw Exception("rate_limit_429");
      } else {
        print(
            "❌ Spotify Auth [$keyName]: Failed. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Spotify Auth [$keyName] Error: $e");
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
        print("🔄 Spotify: Rate limited, trying fallback key...");
        try {
          if (preferPrimary) {
            return await _getAccessTokenSecondary();
          } else {
            return await _getAccessTokenPrimary();
          }
        } catch (e2) {
          print("❌ Spotify: Both keys rate limited!");
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
      // print("Genre Fetch Error: $e");
    }
    return "";
  }

  // --- 3. SEARCH METADATA (Rich Data for Editor) ---
  static Future<List<Map<String, dynamic>>> searchMetadata(String query) async {
    // 🚀 UPDATED: Use SECONDARY key first for metadata, fallback to primary
    final token = await _getTokenWithFallback(preferPrimary: false);
    if (token == null) return [];

    try {
      final uri = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '10',
      });

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 429) throw Exception("rate_limit_429");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List;

        return items.map((item) {
          final album = item['album'];
          final artistsList = (item['artists'] as List);
          final artists =
              artistsList.map((a) => a['name'].toString()).join(", ");

          // Get primary artist ID for genre lookup later
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
            'artist_id': primaryArtistId, // Needed for genre
            'isrc': item['external_ids']?['isrc'], // EXTRACT ISRC
          };
        }).toList();
      }
    } catch (e) {
      print("Metadata Search Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  // --- 3.5 SEARCH BY ISRC ---
  static Future<List<SongMetadata>> searchByIsrc(String isrc) async {
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      // Use the specific 'isrc:code' syntax for highest precision
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
          // Capitalize first letter of artist name for display consistency if needed
          final artistName =
              artistsList.isNotEmpty ? artistsList[0]['name'] : "Unknown";

          String imageUrl = "";
          if ((album['images'] as List).isNotEmpty) {
            imageUrl = album['images'][0]['url'];
          }

          // Fetch genre (optional, but good for consistency)
          // We can skip it for speed or fetch it. Let's stick to "Pop" or basic fetch if critical.
          // For now, let's keep it fast and simple as per requirements.

          return [
            SongMetadata(
              title: item['name'],
              artist: artistName,
              album: album['name'],
              year: (album['release_date'] as String).split('-')[0],
              genre: "Pop", // Default
              trackNumber: item['track_number'],
              discNumber: item['disc_number'],
              durationSeconds: (item['duration_ms'] as int) ~/ 1000,
              albumArtUrl: imageUrl,
              isrc: item['external_ids']?['isrc'], // Capture ISRC
            )
          ];
        }
      }
    } catch (e) {
      print("ISRC Search Error: $e");
    }
    return [];
  }

  // --- 4. SMART DOWNLOAD SEARCH METHOD (New) ---
  /// Searches for tracks using the existing searchMetadata endpoint
  /// and maps the results to the simpler SongMetadata model.
  static Future<List<SongMetadata>> searchTracks(String query) async {
    final rawResults = await searchMetadata(query);

    // We use Future.wait to fetch genres for all tracks in parallel
    final futures = rawResults.map((item) async {
      final String artist = item['artist'] as String;
      final String title = item['title'] as String;
      final int durationMs = item['duration_ms'] as int;
      final String imageUrl = item['image_url'] as String? ?? '';
      final String album = item['album'] as String? ?? 'Unknown Album';
      final String year = item['year'] as String? ?? '';
      final int? trackNum = item['track_number'] as int?;
      final int? discNum = item['disc_number'] as int?;
      final String? isrc = item['isrc'] as String?; // Retrieve from map
      final String? spotifyId = item['spotify_id'] as String?;
      // NEW: Fetch Genre using the Artist ID
      String genre = "Pop"; // Default
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
  static Future<String?> getArtistId({
    required String artistName,
    String? trackTitle,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    String? spotifyArtistId;
    final cleanArtist = _cleanTerm(artistName);
    final cleanTrack = trackTitle != null ? _cleanTerm(trackTitle) : "";

    // Strategy A: Find ID via Track (Most Accurate)
    if (cleanTrack.isNotEmpty) {
      spotifyArtistId =
          await _findArtistIdByTrack(token, cleanArtist, cleanTrack);
    }

    // Strategy B: Find ID via Name (Fallback)
    if (spotifyArtistId == null) {
      spotifyArtistId = await _findArtistIdByName(token, cleanArtist);
    }

    return spotifyArtistId;
  }

  // --- 6. GET FRESH BANNER URL (Custom Backend) ---
  static Future<String?> getFreshBannerUrl(String artistId) async {
    // 1. Try 3rd Party Scraper API (spotifybanner.com logic)
    try {
      final uri = Uri.parse(
          "https://spotify-banner-backend.onrender.com/api/extractbanner");
      // Construct the public Spotify URL
      final String fullSpotifyUrl = "https://open.spotify.com/artist/$artistId";

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body:
            jsonEncode({"artistUrl": fullSpotifyUrl, "deviceType": "desktop"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);

        // Read 'bannerUrl' from the 'data' object based on your response
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'];
          String? banner = data['bannerUrl'];

          // Fallback to imagePath if bannerUrl is missing (and prepend domain)
          if (banner == null && data['imagePath'] != null) {
            banner =
                "https://spotify-banner-backend.onrender.com${data['imagePath']}";
          }

          if (banner != null && banner.isNotEmpty) {
            print("✅ Fetched Banner: $banner");
            return banner;
          }
        }
      }
    } catch (e) {
      print("Backend Banner Error: $e");
    }

    // 2. Try Direct Spotify Web Scrape (The "Inspect Element" method in code)
    try {
      final scrapeUrl = Uri.parse("https://open.spotify.com/artist/$artistId");
      final response = await http.get(scrapeUrl, headers: {
        // Pretend to be a real browser to get the full HTML
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        final html = response.body;

        // 🕵️ LOGIC: Look for the JSON data Spotify embeds in the page
        // Usually inside <script id="initial-state" type="application/json">

        // Regex to find the header image URL directly
        // Pattern: "header_image":{"image":"https://..."}
        final RegExp regex =
            RegExp(r'"header_image":\s*\{\s*"image":\s*"(https:[^"]+)"');
        final match = regex.firstMatch(html);

        if (match != null) {
          String? url = match.group(1);
          // Spotify sometimes escapes forward slashes (e.g. \/), we must fix them
          url = url?.replaceAll(r'\/', '/');
          if (url != null) {
            print("✅ Scraped Banner: $url");
            return url;
          }
        }

        // Fallback: Look for og:image (Usually the square profile, but better than nothing)
        final RegExp ogRegex =
            RegExp(r'<meta property="og:image" content="(https:[^"]+)"');
        final ogMatch = ogRegex.firstMatch(html);
        if (ogMatch != null) {
          return ogMatch.group(1);
        }
      }
    } catch (e) {
      print("Direct Scrape Error: $e");
    }

    return null;
  }

  // --- 7. GET STANDARD ARTIST IMAGE ---
  static Future<String?> getArtistImage({
    required String artistName,
    String? trackTitle,
    bool highQuality = false,
  }) async {
    final token = await _getAccessToken();
    if (token == null) return null;

    final artistId =
        await getArtistId(artistName: artistName, trackTitle: trackTitle);

    if (artistId != null) {
      return await _fetchImageByArtistId(token, artistId, highQuality);
    }
    return null;
  }

  // --- 8. GET TRACK IMAGE & LINK ---

  // 🔑 CRITICAL: Uses SECONDARY key (CLIENT_ID_2) first for Canvas, falls back to PRIMARY
  static Future<String?> getTrackLink(String title, String artist) async {
    // Try SECONDARY (CLIENT_ID_2) first for critical features, fall back to PRIMARY if rate-limited
    final token = await _getTokenWithFallback(preferPrimary: false);
    if (token == null) return null;

    try {
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
          return items[0]['external_urls']['spotify'];
        }
      } else if (response.statusCode == 429) {
        print(
            "⚠️ getTrackLink: API returned 429, token might have been from cached pool");
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  static Future<String?> getTrackImage(String title, String artist) async {
    // 🚀 UPDATED: Use SECONDARY key first for images
    final token = await _getTokenWithFallback(preferPrimary: false);
    if (token == null) return null;

    try {
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
          if (images.isNotEmpty) return images[0]['url'];
        }
      } else if (response.statusCode == 429) {
        throw Exception("rate_limit_429");
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return null;
  }

  // --- 9. GET NEW RELEASES (Dynamic) ---
  static Future<List<Map<String, dynamic>>> getNewReleases(
      {String market = 'US'}) async {
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

        print("✅ New Releases ($market): ${items.length} items");

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
      print("New Releases Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  static Future<List<AlbumModel>> searchAlbums(String query) async {
    final token =
        await _getAccessToken(); // Ensure you have your token logic here

    // Notice type=album here
    final url = Uri.parse(
        'https://api.spotify.com/v1/search?q=$query&type=album&limit=5');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['albums']['items'];
      return items.map((e) => AlbumModel.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> searchAll(String query,
      {int limit = 5}) async {
    // Uses SECONDARY (CLIENT_ID_2) first for remote search, falls back to PRIMARY on 429
    final token = await _getTokenWithFallback(preferPrimary: false);
    if (token == null) {
      return {'songs': [], 'albums': [], 'artists': []};
    }

    // Correct URL for searching (uses $query)
    final url = Uri.parse(
        'https://api.spotify.com/v1/search?q=$query&type=track,album,artist&limit=$limit'); // 🚀 ADDED artist

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

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
          // Fill in required fields manually
          album: e['album']?['name'] ?? "Unknown Album",
          year: year,
          durationSeconds: (e['duration_ms'] ?? 0) ~/ 1000,
          genre: "Pop",
          isrc: e['external_ids']?['isrc'],
          spotifyId: e['id'], // 🚀 CAPTURE SPOTIFY ID
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
    } else if (response.statusCode == 429) {
      throw Exception("rate_limit_429");
    } else {
      return {'songs': [], 'albums': [], 'artists': []};
    }
  }

  // Get tracks for a specific album
  static Future<List<SongMetadata>> getAlbumTracks(String albumId) async {
    final token = await _getAccessToken();

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
        final List fullItems = fullData['tracks'];

        return fullItems.map((e) {
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
      }
    }
    return [];
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
      // print("Error fetching artist image: $e");
    }
    return null;
  }

  // --- 10. GET ARTIST TOP TRACKS (New) ---
  static Future<List<SongMetadata>> getArtistTopTracks(String artistId) async {
    final token = await _getAccessToken();
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
      print("Top Tracks Error: $e");
      if (e.toString().contains("rate_limit_429")) rethrow;
    }
    return [];
  }

  // --- 11. GET ARTIST ALBUMS (Discography) ---
  static Future<List<AlbumModel>> getArtistAlbums(String artistId) async {
    final token = await _getAccessToken();
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
      print("Artist Albums Error: $e");
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
      print("Playlist Info Error: $e");
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

      print("✅ Fetched ${allTracks.length} tracks from playlist");
      return allTracks;
    } catch (e) {
      print("Playlist Tracks Error: $e");
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
  }) async {
    final token = await _getAccessTokenSecondary();
    if (token == null) {
      print("⚠️ getRecommendations: No access token");
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
        print("🌱 getRecommendations: Using seed_tracks: ${tracks.join(',')}");
      }

      if (seedArtists != null && seedArtists.isNotEmpty && seedCount < 5) {
        final artists = seedArtists.take(5 - seedCount).toList();
        params['seed_artists'] = artists.join(',');
        seedCount += artists.length;
        print(
            "🌱 getRecommendations: Using seed_artists: ${artists.join(',')}");
      }

      if (seedGenres != null && seedGenres.isNotEmpty && seedCount < 5) {
        final genres = seedGenres.take(5 - seedCount).toList();
        params['seed_genres'] = genres.join(',');
        print("🌱 getRecommendations: Using seed_genres: ${genres.join(',')}");
      }

      // Must have at least 1 seed
      if (seedCount == 0 && (seedGenres == null || seedGenres.isEmpty)) {
        print("⚠️ getRecommendations: No seeds provided");
        return [];
      }

      final uri = Uri.https('api.spotify.com', '/v1/recommendations', params);
      print("🔗 getRecommendations: Calling URL: $uri");

      final response =
          await http.get(uri, headers: {"Authorization": "Bearer $token"});

      print("📡 getRecommendations: Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks'] as List;

        print("✅ Fetched ${tracks.length} recommendations");

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
        print("❌ Recommendations API Error: ${response.statusCode}");
        print("   Response body: ${response.body}");

        // If 404, maybe the recommendations endpoint isn't available
        // Let's try a fallback to search-based similar tracks
        if (response.statusCode == 404 &&
            seedTracks != null &&
            seedTracks.isNotEmpty) {
          print("🔄 Trying fallback: search for related tracks...");
          return await _getRecommendationsFallback(seedTracks.first, limit);
        }
      }
    } catch (e, stack) {
      print("❌ Recommendations Error: $e");
      print("   Stack: $stack");
    }
    return [];
  }

  /// Fallback method using search to find similar tracks
  static Future<List<SongMetadata>> _getRecommendationsFallback(
      String seedTrackId, int limit) async {
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
        print("❌ Fallback: Could not get track info");
        return [];
      }

      final trackData = jsonDecode(trackResponse.body);
      final artistId = trackData['artists'][0]['id'];
      final artistName = trackData['artists'][0]['name'];

      print("🔄 Fallback: Searching for more tracks by $artistName");

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

        print("✅ Fallback: Found ${tracks.length} tracks by $artistName");

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
      print("❌ Fallback error: $e");
    }
    return [];
  }

  /// Get track ID from title and artist for use as seed
  static Future<String?> getTrackId(String title, String artist) async {
    final token = await _getAccessToken();
    if (token == null) {
      print("⚠️ getTrackId: No access token");
      return null;
    }

    try {
      // Try 1: Exact field search
      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);
      var query = "track:$cleanTitle artist:$cleanArtist";

      print("🔍 getTrackId: Trying exact search: $query");

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
          print("✅ getTrackId: Found with exact search: $id");
          return id;
        }
      }

      // Try 2: Simple search (more lenient)
      query = "$cleanTitle $cleanArtist";
      print("🔍 getTrackId: Trying simple search: $query");

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
              print(
                  "✅ getTrackId: Found with simple search: $id (${track['name']} by ${track['artists'][0]['name']})");
              return id;
            }
          }
          // If no exact match, return first result
          final id = items[0]['id'];
          print("✅ getTrackId: Using first result: $id");
          return id;
        }
      }

      print("⚠️ getTrackId: No results found for '$title' by '$artist'");
    } catch (e) {
      print("❌ getTrackId error: $e");
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
      }
    } catch (e) {/* Ignore */}
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
      }
    } catch (e) {/* Ignore */}
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
      // print("Error fetching best match metadata: $e");
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
          return images.length > 1 ? images[1]['url'] : images[0]['url'];
        }
      }
    } catch (e) {/* Ignore */}
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
}
