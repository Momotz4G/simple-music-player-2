import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:file_picker/file_picker.dart';

/// Cross-platform directory picker that works around bitsdojo_window deadlock
/// on Windows by using file_selector's isolated Dialog instance.
class FolderPicker {
  /// Pick a directory. On Windows, uses file_selector to avoid
  /// file_picker + bitsdojo_window COM dialog deadlock while keeping the modern UI.
  static Future<String?> pickDirectory() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final path = await file_selector.getDirectoryPath();
        if (path != null && path.isNotEmpty) {
          debugPrint("📂 [FolderPicker] Selected: $path");
          return path;
        }
        return null;
      }

      // On Android/iOS file_picker works fine and has optimized local document parsing
      try {
        final path = await FilePicker.platform.getDirectoryPath(lockParentWindow: true);
        if (path != null && path.isNotEmpty) {
          debugPrint("📂 [FolderPicker] Selected: $path");
          return path;
        }
      } catch (e) {
        debugPrint("⚠️ FilePicker Error: $e");
      }
    } catch (e) {
      debugPrint("⚠️ [FolderPicker] Exception: $e");
    }
    return null;
  }
}
