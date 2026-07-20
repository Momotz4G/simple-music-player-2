import 'package:isar/isar.dart';
part 'schemas.g.dart';

@collection
class Song {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false)
  late String path;

  late String title;
  late String artist;
  String? album;

  late double duration;

  late DateTime dateAdded;

  int playCount = 0;

  // ReplayGain for Loudness Scanner
  double? replayGain;
  DateTime? lastPlayed;

  // Store the dominant color (int) for UI theming
  int? accentColor;

  String? year;
  int? trackNumber;
  int? discNumber;
  String? genre;
}

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  late String name;

  late DateTime createdAt;

  final songs = IsarLinks<Song>();
}

@collection
class HistoryEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime lastPlayed;

  // Core Metadata (To show in UI even if file is gone)
  late String title;
  late String artist;
  late String album;
  late String albumArtUrl;
  late double duration;

  // Playback Data
  late String originalFilePath;
  late String youtubeUrl;
  late bool isStream; // Was it a stream or a local file?

  // Extended Metadata
  String? spotifyId;
  String? deezerId;
}

@collection
class SavedStat {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String statId;

  late String title;

  late String artist;
  late String album;

  late int playCount;
  late int totalSeconds;

  DateTime? lastPlayed;

  late String lastKnownPath;

  // METADATA PERSISTENCE
  String? onlineArtUrl;
  String? youtubeUrl;
  String? spotifyId;
  String? deezerId;
}

@collection
class MailboxMessage {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? remoteId;

  late String message;

  @Index()
  late DateTime timestamp;

  @Index()
  bool isRead = false;
}

@collection
class DeletedMailboxMessage {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String remoteId;
}

@collection
class OnlineArtCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String url;

  late DateTime lastUpdated;
}

@collection
class OnlineDataCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String json;

  late DateTime lastUpdated;
}
