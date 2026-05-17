/// Re-exports the SyncQueueEntry Isar collection from the central schemas file.
///
/// The SyncQueueEntry collection is defined in `lib/data/schemas.dart` to follow
/// the project's convention of keeping all Isar collections in a single file
/// for code generation purposes.
///
/// Validates: Requirements 4.1, 4.4
library sync_queue_entry;

export 'package:simple_music_player_2/data/schemas.dart' show SyncQueueEntry;
