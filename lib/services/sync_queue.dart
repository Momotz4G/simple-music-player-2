import '../models/stat_delta.dart';

/// In-memory queue for offline stat changes.
///
/// Note: Switch back to Isar-based persistence once build_runner
/// regenerates schemas.g.dart with SyncQueueEntry support.
///
/// Validates: Requirements 4.1, 4.2, 4.3, 4.4
class SyncQueue {
  static final SyncQueue _instance = SyncQueue._internal();
  factory SyncQueue() => _instance;
  SyncQueue._internal();

  final List<StatDelta> _queue = [];

  /// Enqueues a [StatDelta] to the in-memory queue.
  Future<void> enqueue(StatDelta delta) async {
    _queue.add(delta);
  }

  /// Returns all queued deltas sorted by timestamp ascending (oldest first).
  Future<List<StatDelta>> dequeueAll() async {
    final sorted = List<StatDelta>.from(_queue)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  /// Removes a completed entry from the queue by its delta ID.
  Future<void> markCompleted(String deltaId) async {
    _queue.removeWhere((d) => d.id == deltaId);
  }

  /// Retains a failed entry for retry (no-op — it stays in queue).
  Future<void> retainFailed(String deltaId) async {
    // No-op: failed entries stay in the queue
  }

  /// Returns the number of pending entries.
  Future<int> get pendingCount async => _queue.length;

  /// Clears all entries from the queue.
  Future<void> clear() async {
    _queue.clear();
  }
}
