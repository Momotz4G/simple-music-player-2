class FilenameHelper {
  /// Standardized sanitization for filenames across all services.
  /// Replaces illegal characters [\/ : * ? " < > |] with underscores.
  /// Keeps spaces and apostrophes for readability and consistency.
  static String sanitize(String filename) {
    // 1. Remove/Replace illegal file system characters
    // Using a milder regex that allows spaces, parentheses, etc.
    final sanitized = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    
    // 2. Truncate to a safe length (NTFS/APFS allow ~255, we use 200)
    if (sanitized.length > 200) {
      return sanitized.substring(0, 200);
    }
    
    return sanitized;
  }
}
