import 'package:isar/isar.dart';

// This line is needed for the code generator
// The file name must match: 'schemas.g.dart'
part 'schemas.g.dart';

@collection
class Song {
  Id id = Isar.autoIncrement; // Isar automatically handles IDs

  // We index the path because we search by it constantly.
  // 'unique: true' ensures we don't save the same file twice.
  @Index(unique: true, replace: false)
  late String path;

  late String title;
  late String artist;
  late String? album;

  late double duration; // Stored in seconds

  // Optional: Store file modification time to detect updates
  late DateTime dateAdded;

  // --- Statistics Embedded ---
  // Storing stats directly on the Song object makes queries instant.
  // e.g., isar.songs.where().sortByPlayCountDesc().findAll()
  int playCount = 0;
  DateTime? lastPlayed;

  // Store the dominant color (int) for UI theming
  int? accentColor;
}

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  late String name;

  late DateTime createdAt;

  // IsarLinks creates a relationship.
  // A playlist "contains" many songs.
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
  late String albumArtUrl; // Store URL so we can re-download art if needed
  late double duration;

  // Playback Data
  late String originalFilePath; // Where it WAS stored
  late String youtubeUrl; // How to get it back
  late bool isStream; // Was it a stream or a local file?
}

@collection
class SavedStat {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String statId; // The hash ID we used before

  late String title;
  late String artist;
  late String album;

  late int playCount;
  late int totalSeconds;

  late String lastKnownPath;

  // METADATA PERSISTENCE
  late String? onlineArtUrl;
  late String? youtubeUrl;
}
