import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgDark = Color(0xFF0A0D14);
  static const Color sidebarDark = Color(0xFF10141D);
  static const Color cardDark = Color(0xFF161B26);
  static const Color cardHover = Color(0xFF1C2230);
  static const Color borderDark = Color(0xFF232B3B);

  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentBlue = Color(0xFF3A7BD5);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentPurple = Color(0xFF9D4EDD);

  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentCyan,
        surface: cardDark,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
