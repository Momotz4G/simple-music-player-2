import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Use a predefined set of colors for the UI (similar to Spotube/Vibes)
  static const Color darkPrimaryColor =
      Color(0xFF6C5CE7); // Deep Purple/Blue Accent
  static const Color darkBackgroundColor =
      Color(0xFF0C131B); // Very dark background
  static const Color darkCardColor = Color(0xFF141F2B); // Sidebar/Card color

  static ThemeData darkTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      canvasColor:
          darkBackgroundColor, // Default background for drawers/dialogs
      cardColor: darkCardColor, // Used for the Sidebar
      dividerColor: Colors.white10,
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor.withOpacity(0.8),
        surface: darkCardColor,
        background: darkBackgroundColor,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        selectedTileColor: accentColor.withOpacity(0.1),
        iconColor: Colors.white70,
        selectedColor: accentColor,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }

  // Placeholder for light theme (required by main.dart)
  static ThemeData lightTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: accentColor,
      useMaterial3: true,
      // Add more customization if needed
    );
  }
}
