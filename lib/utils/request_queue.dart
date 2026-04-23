import 'dart:async';
import 'dart:collection';

/// A simple queue to limit concurrent requests
class RequestQueue {
  final int maxConcurrent;
  int _currentRunning = 0;
  final _queue = Queue<_Task>();

  RequestQueue({this.maxConcurrent = 2});

  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue.add(_Task(task, completer));
    _process();
    return completer.future;
  }

  void _process() async {
    if (_currentRunning >= maxConcurrent || _queue.isEmpty) return;

    _currentRunning++;
    final task = _queue.removeFirst();

    try {
      final result = await task.run();
      task.completer.complete(result);
    } catch (e) {
      task.completer.completeError(e);
    } finally {
      _currentRunning--;
      _process();
    }
  }
}

class _Task {
  final Function run;
  final Completer completer;
  _Task(this.run, this.completer);
}

// Global instance for images
final imageRequestQueue = RequestQueue(maxConcurrent: 5);
