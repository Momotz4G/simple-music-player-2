import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:file_picker/file_picker.dart' as fp;

/// Cross-platform file picker that routes to the appropriate plugin per
/// platform.
///
/// PLATFORM CHOICES:
///  • Desktop (Windows/macOS/Linux) → [file_selector]
///      Avoids the documented `file_picker + bitsdojo_window` COM-dialog
///      deadlock (see [FolderPicker]).
///  • Mobile (Android/iOS) → [file_picker]
///      Uses native SAF (Android) / UIDocumentPickerViewController (iOS),
///      which is the only way to access non-MediaStore files.
///
/// SAVE-FILE NUANCE ON ANDROID:
///  On Android the save dialog returns a SAF `content://` URI, not a real
///  filesystem path. `dart:io File(...).writeAsString(...)` cannot write
///  to that URI. The supported approach is to pass the bytes directly to
///  the plugin and let the native side write through SAF. We expose
///  [saveBytes] for that purpose. Desktop callers can also use it; we
///  transparently write the bytes to the chosen path on those platforms.
class FilePickerHelper {
  /// Pick a single file matching one of [extensions] (without leading dot).
  /// Returns the absolute path or null if the user cancelled.
  ///
  /// On Android the plugin copies the chosen SAF document into the app's
  /// cache and returns that real path, so callers can use [File] directly.
  static Future<String?> pickFile({required List<String> extensions}) async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final typeGroup = fs.XTypeGroup(
          label: extensions.join(', '),
          extensions: extensions,
        );
        final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
        return file?.path;
      }

      // Mobile path. file_picker on Android uses ACTION_OPEN_DOCUMENT and
      // mirrors the chosen file to local cache, returning a real path.
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: extensions,
      );
      return result?.files.single.path;
    } catch (e) {
      debugPrint(" [FilePickerHelper] pickFile error: $e");
      return null;
    }
  }

  /// Save [bytes] to a user-chosen location. Returns the resulting path
  /// (or null if the user cancelled / the write failed).
  ///
  /// This is the recommended save API: it works on every platform without
  /// the caller needing to know whether the picker returned a real path
  /// or a SAF URI.
  static Future<String?> saveBytes({
    required String suggestedName,
    required List<String> extensions,
    required Uint8List bytes,
    String? dialogTitle,
  }) async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final typeGroup = fs.XTypeGroup(
          label: extensions.join(', '),
          extensions: extensions,
        );
        final location = await fs.getSaveLocation(
          acceptedTypeGroups: [typeGroup],
          suggestedName: suggestedName,
        );
        if (location == null) return null;

        var path = location.path;
        // Make sure the file ends with one of the allowed extensions.
        // Some Linux/macOS save dialogs don't auto-append it.
        final lower = path.toLowerCase();
        final hasExt =
            extensions.any((e) => lower.endsWith('.${e.toLowerCase()}'));
        if (!hasExt && extensions.isNotEmpty) {
          path = '$path.${extensions.first}';
        }

        await File(path).writeAsBytes(bytes);
        return path;
      }

      // Mobile: hand the bytes to the plugin so it can write via SAF on
      // Android (or the share-sheet equivalent on iOS). file_picker's
      // saveFile returns the resulting path (which on Android may be a
      // SAF `content://` path that's already been written by the plugin).
      return await fp.FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'Save As',
        fileName: suggestedName,
        type: fp.FileType.custom,
        allowedExtensions: extensions,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint(" [FilePickerHelper] saveBytes error: $e");
      return null;
    }
  }
}
