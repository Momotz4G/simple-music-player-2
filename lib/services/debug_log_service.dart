import 'package:flutter/foundation.dart';

/// A simple in-app debug log service that captures debug messages
/// and makes them available for display in a debug panel.
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<DebugLogEntry> _logs = [];
  final List<VoidCallback> _listeners = [];

  static const int maxLogs = 500;

  List<DebugLogEntry> get logs => List.unmodifiable(_logs);

  /// Add a log entry
  void log(String message, {DebugLogLevel level = DebugLogLevel.info}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );

    _logs.add(entry);

    // Keep only the last maxLogs entries
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Also print to console for debugging
    debugPrint('[${level.name.toUpperCase()}] $message');

    // Notify listeners
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Add a listener for log updates
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Convenience methods
  void info(String message) => log(message, level: DebugLogLevel.info);
  void success(String message) => log(message, level: DebugLogLevel.success);
  void warning(String message) => log(message, level: DebugLogLevel.warning);
  void error(String message) => log(message, level: DebugLogLevel.error);
}

enum DebugLogLevel {
  info,
  success,
  warning,
  error,
}

class DebugLogEntry {
  final DateTime timestamp;
  final String message;
  final DebugLogLevel level;

  DebugLogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
