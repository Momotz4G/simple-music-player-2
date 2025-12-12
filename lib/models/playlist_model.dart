import 'dart:convert';

class PlaylistEntry {
  final String path;
  final DateTime dateAdded;
  // METADATA CACHE (For streamed/missing songs)
  final String? title;
  final String? artist;
  final String? album;
  final String? artUrl;
  final String? sourceUrl;
  final String? isrc; // 🚀 ADD ISRC
  final int? duration; // 🚀 ADD DURATION (Seconds)

  PlaylistEntry({
    required this.path,
    required this.dateAdded,
    this.title,
    this.artist,
    this.album,
    this.artUrl,
    this.sourceUrl,
    this.isrc,
    this.duration,
  });

  Map<String, dynamic> toMap() => {
        'path': path,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
        'title': title,
        'artist': artist,
        'album': album,
        'artUrl': artUrl,
        'sourceUrl': sourceUrl,
        'isrc': isrc,
        'duration': duration,
      };

  factory PlaylistEntry.fromMap(Map<String, dynamic> map) {
    return PlaylistEntry(
      path: map['path'] ?? '',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] ?? 0),
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      artUrl: map['artUrl'],
      sourceUrl: map['sourceUrl'],
      isrc: map['isrc'],
      duration: map['duration'],
    );
  }
}

class PlaylistModel {
  final String id;
  final String name;
  final List<PlaylistEntry> entries; // Changed from List<String>
  final DateTime createdAt;
  final String? coverUrl; // 🚀 For Spotify imported playlists

  PlaylistModel({
    required this.id,
    required this.name,
    required this.entries,
    required this.createdAt,
    this.coverUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'entries': entries.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'coverUrl': coverUrl,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      entries: List<PlaylistEntry>.from(
        (map['entries'] ?? []).map((x) => PlaylistEntry.fromMap(x)),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      coverUrl: map['coverUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) =>
      PlaylistModel.fromMap(json.decode(source));

  PlaylistModel copyWith({
    String? name,
    List<PlaylistEntry>? entries,
    String? coverUrl,
  }) {
    return PlaylistModel(
      id: id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
      createdAt: createdAt,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}
