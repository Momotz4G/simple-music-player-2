import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song_metadata.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import 'package:flutter/foundation.dart';

class ITunesApiService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  /// Search the iTunes API and return SongMetadata objects.
  static Future<List<SongMetadata>> searchSongs(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$_baseUrl?term=$encodedQuery&entity=song&limit=$limit&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        return results.map((track) {
          final artist = track['artistName'] as String? ?? 'Unknown Artist';
          final title = track['trackName'] as String? ?? 'Unknown Title';
          final album = track['collectionName'] as String? ?? '';
          
          // iTunes returns duration in milliseconds
          final trackTimeMillis = track['trackTimeMillis'] as int? ?? 0;
          final durationSeconds = trackTimeMillis ~/ 1000;

          // Apple Music URL
          final trackViewUrl = track['trackViewUrl'] as String? ?? '';

          // High-Res Artwork
          String artUrl = track['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          // Create SongMetadata
          // We map iTunes URL to spotifyUrl or youtubeUrl or a custom field.
          // Since the app probably expects one of these for the deep search later,
          // we will place the Apple Music URL in `url` field if your SongMetadata supports it, 
          // or we can just pass it through the existing structures.
          return SongMetadata(
            title: title,
            artist: artist,
            album: album,
            durationSeconds: durationSeconds,
            albumArtUrl: artUrl,
            // You can temporarily store the apple music url in youtubeUrl or a new field
            // if you need it for downloading. For now, we put it in youtubeUrl so it can be played/passed.
            youtubeUrl: trackViewUrl,
          );
        }).toList();
      } else {
        debugPrint('iTunes API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('iTunes Search Exception: $e');
      return [];
    }
  }

  /// Get Tracks for a Specific Album
  static Future<List<SongMetadata>> getAlbumTracks(String collectionId) async {
    if (collectionId.trim().isEmpty) return [];

    final url = Uri.parse('https://itunes.apple.com/lookup?id=$collectionId&entity=song&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final List<SongMetadata> tracks = [];
        int trackNumber = 1;

        for (final item in results) {
          // The first result is usually the album itself (wrapperType == 'collection')
          if (item['wrapperType'] != 'track') continue;

          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final album = item['collectionName'] as String? ?? '';
          
          final trackTimeMillis = item['trackTimeMillis'] as int? ?? 0;
          final durationSeconds = trackTimeMillis ~/ 1000;

          final trackViewUrl = item['trackViewUrl'] as String? ?? '';

          String artUrl = item['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          final discNumber = item['discNumber'] as int? ?? 1;
          final trackNum = item['trackNumber'] as int? ?? trackNumber;

          tracks.add(SongMetadata(
            title: title,
            artist: artist,
            album: album,
            durationSeconds: durationSeconds,
            albumArtUrl: artUrl,
            youtubeUrl: trackViewUrl, // Passing Apple Music URL here
            trackNumber: trackNum,
            discNumber: discNumber,
          ));
          
          trackNumber++;
        }
        return tracks;
      }
    } catch (e) {
      debugPrint('iTunes getAlbumTracks Exception: $e');
    }
    return [];
  }

  /// Search iTunes API for Albums
  static Future<List<AlbumModel>> searchAlbums(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$_baseUrl?term=$encodedQuery&entity=album&limit=$limit&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        return results.map((item) {
          final title = item['collectionName'] as String? ?? 'Unknown Album';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final id = (item['collectionId'] as int?)?.toString() ?? '';
          final releaseDate = item['releaseDate'] as String? ?? '';
          
          String artUrl = item['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          return AlbumModel(
            id: id,
            title: title,
            artist: artist,
            imageUrl: artUrl,
            releaseDate: releaseDate,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('iTunes Album Search Exception: $e');
    }
    return [];
  }

  /// Search iTunes API for Artists
  static Future<List<ArtistModel>> searchArtists(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$_baseUrl?term=$encodedQuery&entity=musicArtist&limit=$limit&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        return results.map((item) {
          final name = item['artistName'] as String? ?? 'Unknown Artist';
          final id = (item['artistId'] as int?)?.toString() ?? '';
          
          // iTunes API often doesn't return artwork for musicArtist entity
          return ArtistModel(
            id: id,
            name: name,
            imageUrl: '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('iTunes Artist Search Exception: $e');
    }
    return [];
  }

  /// Concurrently fetch Songs, Albums, and Artists
  static Future<Map<String, dynamic>> searchAll(String query, {int limit = 5}) async {
    final songsFuture = searchSongs(query, limit: limit);
    final albumsFuture = searchAlbums(query, limit: limit);
    final artistsFuture = searchArtists(query, limit: limit);

    final results = await Future.wait([songsFuture, albumsFuture, artistsFuture]);

    final List<SongMetadata> songs = results[0] as List<SongMetadata>;
    final List<AlbumModel> albums = results[1] as List<AlbumModel>;
    final List<ArtistModel> artists = results[2] as List<ArtistModel>;

    // Zero-cost Artist Image Injection (Apple Music API doesn't return artist images)
    final enrichedArtists = artists.map((artist) {
      if (artist.imageUrl.isEmpty) {
        // 1. Try to steal the image from a matching song
        try {
          final matchSong = songs.firstWhere((s) => s.artist.toLowerCase().contains(artist.name.toLowerCase()));
          return ArtistModel(id: artist.id, name: artist.name, imageUrl: matchSong.albumArtUrl);
        } catch (_) {}
        
        // 2. Try to steal the image from a matching album
        try {
          final matchAlbum = albums.firstWhere((a) => a.artist.toLowerCase().contains(artist.name.toLowerCase()));
          return ArtistModel(id: artist.id, name: artist.name, imageUrl: matchAlbum.imageUrl);
        } catch (_) {}
      }
      return artist;
    }).toList();

    return {
      'songs': songs,
      'albums': albums,
      'artists': enrichedArtists,
    };
  }
  /// Get iTunes Artist ID from Artist Name
  static Future<String?> getArtistId(String artistName) async {
    final artists = await searchArtists(artistName, limit: 1);
    if (artists.isNotEmpty) {
      return artists.first.id;
    }
    return null;
  }

  /// Get Artist Top Tracks
  static Future<List<SongMetadata>> getArtistTopTracks(String artistId, {int limit = 10}) async {
    if (artistId.trim().isEmpty) return [];

    final url = Uri.parse('https://itunes.apple.com/lookup?id=$artistId&entity=song&limit=$limit&sort=popular&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final List<SongMetadata> tracks = [];

        for (final item in results) {
          if (item['wrapperType'] != 'track') continue;

          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final album = item['collectionName'] as String? ?? '';
          
          final trackTimeMillis = item['trackTimeMillis'] as int? ?? 0;
          final durationSeconds = trackTimeMillis ~/ 1000;

          final trackViewUrl = item['trackViewUrl'] as String? ?? '';

          String artUrl = item['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          tracks.add(SongMetadata(
            title: title,
            artist: artist,
            album: album,
            durationSeconds: durationSeconds,
            albumArtUrl: artUrl,
            youtubeUrl: trackViewUrl,
          ));
        }
        return tracks;
      }
    } catch (e) {
      debugPrint('iTunes getArtistTopTracks Exception: $e');
    }
    return [];
  }

  /// Get Artist Albums (Discography)
  static Future<List<AlbumModel>> getArtistAlbums(String artistId, {int limit = 50}) async {
    if (artistId.trim().isEmpty) return [];

    final url = Uri.parse('https://itunes.apple.com/lookup?id=$artistId&entity=album&limit=$limit&sort=recent&country=id');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final List<AlbumModel> albums = [];

        for (final item in results) {
          if (item['wrapperType'] != 'collection') continue;

          final title = item['collectionName'] as String? ?? 'Unknown Album';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final id = (item['collectionId'] as int?)?.toString() ?? '';
          final releaseDate = item['releaseDate'] as String? ?? '';
          
          String artUrl = item['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          albums.add(AlbumModel(
            id: id,
            title: title,
            artist: artist,
            imageUrl: artUrl,
            releaseDate: releaseDate,
          ));
        }
        return albums;
      }
    } catch (e) {
      debugPrint('iTunes getArtistAlbums Exception: $e');
    }
    return [];
  }
}
