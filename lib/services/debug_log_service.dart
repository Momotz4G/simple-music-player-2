import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// A simple in-app debug log service that captures debug messages
/// and makes them available for display in a debug panel.
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<DebugLogEntry> _logs = [];
  final List<VoidCallback> _listeners = [];
  final List<String> _fileBuffer = []; // 🚀 LOG BUFFER FOR BATCH RECORDING
  Timer? _flushTimer;
  String? _logsDirPath;

  static const int maxLogs = 500;

  List<DebugLogEntry> get logs => List.unmodifiable(_logs);

  Future<void> _initLogFile() async {
    if (_logsDirPath != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Drop the logs exactly next to the ISAR default.isar file
      final logsDir = Directory(p.join(dir.path, 'SimpleMusicDB', 'logs'));
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      _logsDirPath = logsDir.path;
      
      // Cleanup logs older than 3 days in the background
      _cleanupOldLogs(logsDir);
    } catch (_) {
      // Log initialization failed
    }
  }

  void _cleanupOldLogs(Directory logsDir) {
    try {
      final now = DateTime.now();
      // Define the cutoff time as exactly 3 days ago from now
      final cutoff = now.subtract(const Duration(days: 3));
      
      final files = logsDir.listSync();
      for (var entity in files) {
        if (entity is File && entity.path.contains('app_console_log_')) {
          final lastModified = entity.lastModifiedSync();
          // Delete safely if it violates the 3 days limit
          if (lastModified.isBefore(cutoff)) {
            entity.deleteSync();
          }
        }
      }
    } catch (_) {}
  }

  void _appendToFile(String formattedMessage) {
    _fileBuffer.add(formattedMessage);
    
    // Start flush timer on first message
    _flushTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      _flushBuffer();
    });
  }

  Future<void> _flushBuffer() async {
    if (_fileBuffer.isEmpty) {
       _flushTimer?.cancel();
       _flushTimer = null;
       return;
    }

    if (_logsDirPath == null) {
      await _initLogFile();
    }

    if (_logsDirPath != null && _fileBuffer.isNotEmpty) {
      try {
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final filePath = p.join(_logsDirPath!, 'app_console_log_$dateStr.txt');
        
        final List<String> batch = List.from(_fileBuffer);
        _fileBuffer.clear();
        final file = File(filePath);
        String content = '${batch.join('\n')}\n';
        await file.writeAsString(content, mode: FileMode.append);
      } catch (_) {
        // Silent fail on write
      }
    }
  }

  /// Add a log entry
  void log(String message, {DebugLogLevel level = DebugLogLevel.info}) {
    // 🛡️ SECURITY: Mask private domains to protect backend location from floating debug window/logs
    String maskedMessage = message;
    if (maskedMessage.contains('stephanus-dev')) {
      // Completely mask any subdomain and the .online extension
      final domainRegex = RegExp(r'[a-zA-Z0-9.-]*stephanus-dev\.online');
      maskedMessage = maskedMessage.replaceAll(domainRegex, '[hidden-domain]');
      maskedMessage = maskedMessage.replaceAll('stephanus-dev', '[hidden-host]');
    }

    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      message: maskedMessage,
      level: level,
    );

    _logs.add(entry);

    // Keep only the last maxLogs entries
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Format console output
    final logFormatted = '[${entry.formattedTime}] [${level.name.toUpperCase()}] $maskedMessage';

    // Also print to console for debugging
    debugPrint(logFormatted);

    // Write to logs folder automatically via async
    _appendToFile(logFormatted);

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
