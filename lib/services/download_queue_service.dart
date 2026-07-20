// lib/services/download_queue_service.dart

// Serializes single-song downloads so they run one at a time.
// Exposes a ValueNotifier<List<DownloadQueueItem>> for the UI.

import 'dart:async';
import 'package:flutter/foundation.dart';

// ─── Queue item status ────────────────────────────────────────────────────────

enum DownloadQueueStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadQueueItem {
  final String id; // unique per enqueue call
  final String title;
  final String artist;
  final String? artUrl;
  DownloadQueueStatus status;
  double progress; // 0.0 – 1.0
  String statusLabel;
  double receivedMB; // bytes downloaded so far
  double totalMB; // estimated total size
  double? speedMBps; // current speed

  DownloadQueueItem({
    required this.id,
    required this.title,
    required this.artist,
    this.artUrl,
    this.status = DownloadQueueStatus.queued,
    this.progress = 0.0,
    this.statusLabel = 'Queued',
    this.receivedMB = 0.0,
    this.totalMB = 0.0,
    this.speedMBps,
  });

  DownloadQueueItem copyWith({
    DownloadQueueStatus? status,
    double? progress,
    String? statusLabel,
    double? receivedMB,
    double? totalMB,
    double? speedMBps,
    bool clearSpeed = false,
  }) {
    return DownloadQueueItem(
      id: id,
      title: title,
      artist: artist,
      artUrl: artUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusLabel: statusLabel ?? this.statusLabel,
      receivedMB: receivedMB ?? this.receivedMB,
      totalMB: totalMB ?? this.totalMB,
      speedMBps: clearSpeed ? null : (speedMBps ?? this.speedMBps),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

typedef DownloadTask = Future<void> Function(
  String itemId,
  void Function(double progress, String label,
          {double receivedMB, double totalMB, double? speedMBps})
      onProgress,
  void Function() onComplete,
  void Function(String error) onError,
);

class DownloadQueueService {
  // Singleton
  static final DownloadQueueService _instance =
      DownloadQueueService._internal();
  factory DownloadQueueService() => _instance;
  DownloadQueueService._internal();

  // ── Public state ────────────────────────────────────────────────────────────

  /// Full queue list (queued + active + completed/failed).
  final ValueNotifier<List<DownloadQueueItem>> queueNotifier =
      ValueNotifier([]);

  /// True while any download is running.
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier(false);

  // ── Private state ───────────────────────────────────────────────────────────

  final List<_PendingTask> _pending = [];
  bool _isRunning = false;
  
  /// Set of IDs that have been cancelled. Tasks check this to abort early.
  final Set<String> _cancelledIds = {};

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Check if an item has been cancelled (tasks can poll this to abort).
  bool isCancelled(String id) => _cancelledIds.contains(id);

  /// Number of tasks currently waiting in the queue
  int get pendingCount => _pending.length;

  /// Enqueue a download. Returns the assigned item ID.
  String enqueue({
    required String title,
    required String artist,
    String? artUrl,
    required DownloadTask task,
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}';

    final item = DownloadQueueItem(
      id: id,
      title: title,
      artist: artist,
      artUrl: artUrl,
    );

    _pending.add(_PendingTask(item: item, task: task));
    _updateNotifier();
    _processNext();
    return id;
  }

  /// Cancel a queued or active item.
  void cancelItem(String id) {
    // Mark as cancelled
    _cancelledIds.add(id);
    
    // Remove from pending if it's queued
    _pending.removeWhere((t) => t.item.id == id);

    bool wasDownloading = false;

    _updateItems((items) {
      final idx = items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        if (items[idx].status == DownloadQueueStatus.downloading) {
          wasDownloading = true;
        }
        items[idx] = items[idx].copyWith(
          status: DownloadQueueStatus.cancelled,
          statusLabel: 'Cancelled',
        );
      }
    });

    // If it was downloading, force start the next one.
    if (wasDownloading) {
      _isRunning = false;
      _processNext();
    }
  }

  /// Cancel all queued and active items.
  void cancelAll() {
    // Mark all as cancelled
    for (final t in _pending) {
      _cancelledIds.add(t.item.id);
    }
    _pending.clear();
    
    _updateItems((items) {
      for (int i = 0; i < items.length; i++) {
        if (items[i].status == DownloadQueueStatus.queued ||
            items[i].status == DownloadQueueStatus.downloading) {
          _cancelledIds.add(items[i].id);
          items[i] = items[i].copyWith(
            status: DownloadQueueStatus.cancelled,
            statusLabel: 'Cancelled',
          );
        }
      }
    });
    _isRunning = false;
    // Don't process next — everything is cancelled
  }

  /// Remove completed / failed / cancelled items from the visible list.
  void clearFinished() {
    _updateItems((items) {
      // Clean up cancelled IDs that are being removed
      for (final item in items) {
        if (item.status == DownloadQueueStatus.completed ||
            item.status == DownloadQueueStatus.failed ||
            item.status == DownloadQueueStatus.cancelled) {
          _cancelledIds.remove(item.id);
        }
      }
      items.removeWhere((i) =>
          i.status == DownloadQueueStatus.completed ||
          i.status == DownloadQueueStatus.failed ||
          i.status == DownloadQueueStatus.cancelled);
    });
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _processNext() {
    if (_isRunning || _pending.isEmpty) return;
    _isRunning = true;
    isActiveNotifier.value = true;

    final next = _pending.removeAt(0);
    
    // Skip if already cancelled before it started
    if (_cancelledIds.contains(next.item.id)) {
      _isRunning = false;
      _processNext();
      return;
    }
    
    _setItemStatus(
      next.item.id,
      DownloadQueueStatus.downloading,
      0.0,
      'Downloading…',
    );

    // Track whether the task called onComplete/onError
    bool taskFinished = false;

    // Run the task and handle all outcomes
    next.task(
      next.item.id,
      // onProgress
      (progress, label,
          {double receivedMB = 0, double totalMB = 0, double? speedMBps}) {
        // Skip updates if it was cancelled
        if (_cancelledIds.contains(next.item.id)) return;
        
        final items = queueNotifier.value;
        final idx = items.indexWhere((i) => i.id == next.item.id);
        if (idx == -1 || items[idx].status == DownloadQueueStatus.cancelled) return;

        _setItemStatus(
          next.item.id,
          DownloadQueueStatus.downloading,
          progress,
          label,
          receivedMB: receivedMB,
          totalMB: totalMB,
          speedMBps: speedMBps,
        );
      },
      // onComplete
      () {
        if (taskFinished) return; // Prevent double-complete
        taskFinished = true;
        
        if (_cancelledIds.contains(next.item.id)) return;
        
        final items = queueNotifier.value;
        final idx = items.indexWhere((i) => i.id == next.item.id);
        if (idx == -1 || items[idx].status == DownloadQueueStatus.cancelled) return;

        _setItemStatus(
          next.item.id,
          DownloadQueueStatus.completed,
          1.0,
          'Complete',
        );
        _finishCurrent();
      },
      // onError
      (error) {
        if (taskFinished) return; // Prevent double-complete
        taskFinished = true;
        
        if (_cancelledIds.contains(next.item.id)) return;
        
        final items = queueNotifier.value;
        final idx = items.indexWhere((i) => i.id == next.item.id);
        if (idx == -1 || items[idx].status == DownloadQueueStatus.cancelled) return;

        _setItemStatus(
          next.item.id,
          DownloadQueueStatus.failed,
          0.0,
          'Failed',
        );
        _finishCurrent();
      },
    ).then((_) {
      // Safety net: if the task's Future resolved but it never called
      // onComplete/onError (e.g., a fire-and-forget callback pattern),
      // wait a bit and then force-advance the queue.
      if (!taskFinished && !_cancelledIds.contains(next.item.id)) {
        // The task returned without calling onComplete/onError.
        // This is fine for callback-based patterns (like yt-dlp's onComplete).
        // But if it truly forgot, we'll catch it after a timeout.
        Future.delayed(const Duration(minutes: 5), () {
          if (!taskFinished && _isRunning) {
            debugPrint('⚠️ DownloadQueue: Task ${next.item.id} timed out without completion. Force-advancing queue.');
            taskFinished = true;
            _setItemStatus(next.item.id, DownloadQueueStatus.failed, 0.0, 'Timed out');
            _finishCurrent();
          }
        });
      }
    }).catchError((e) {
      // If the task itself throws an uncaught exception
      if (!taskFinished) {
        taskFinished = true;
        debugPrint('⚠️ DownloadQueue: Task ${next.item.id} threw: $e');
        _setItemStatus(next.item.id, DownloadQueueStatus.failed, 0.0, 'Error');
        _finishCurrent();
      }
    });
  }

  void _finishCurrent() {
    _isRunning = false;
    isActiveNotifier.value = _pending.isNotEmpty;
    _processNext();
  }

  void _setItemStatus(
    String id,
    DownloadQueueStatus status,
    double progress,
    String label, {
    double receivedMB = 0,
    double totalMB = 0,
    double? speedMBps,
  }) {
    _updateItems((items) {
      final idx = items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        items[idx] = items[idx].copyWith(
          status: status,
          progress: progress,
          statusLabel: label,
          receivedMB: receivedMB,
          totalMB: totalMB,
          speedMBps: speedMBps,
          clearSpeed: speedMBps == null,
        );
      }
    });
  }

  void _updateItems(void Function(List<DownloadQueueItem>) mutate) {
    final copy = List<DownloadQueueItem>.from(queueNotifier.value);
    mutate(copy);
    queueNotifier.value = copy;
  }

  void _updateNotifier() {
    // Merge pending tasks into the notifier list (add new items)
    final existing = List<DownloadQueueItem>.from(queueNotifier.value);
    for (final t in _pending) {
      if (!existing.any((i) => i.id == t.item.id)) {
        existing.add(t.item);
      }
    }
    queueNotifier.value = existing;
  }
}

class _PendingTask {
  final DownloadQueueItem item;
  final DownloadTask task;
  _PendingTask({required this.item, required this.task});
}
