import 'package:flutter/material.dart';

class AppTheme {
  // --- Modern Developer Surface & Palette (Obsidian / Zinc) ---
  static const Color bgDark = Color(0xFF0D0F14);
  static const Color sidebarDark = Color(0xFF11141A);
  static const Color cardDark = Color(0xFF151922);
  static const Color bgCard = cardDark;
  static const Color cardHover = Color(0xFF1B202B);
  static const Color borderDark = Color(0xFF232836);
  static const Color borderSubtle = Color(0xFF1D222E);
  static const Color surfaceSubtle = Color(0xFF12151D);
  static const Color surfaceElevated = Color(0xFF1A1F2B);

  // --- Refined Functional Accents (Not Neon AI Slop) ---
  static const Color accentIndigo = Color(0xFF6366F1); // Modern primary
  static const Color accentBlue = Color(0xFF4F46E5);   // Indigo-600
  static const Color accentCyan = Color(0xFF0EA5E9);   // Refined Sky-500
  static const Color accentGreen = Color(0xFF10B981);  // Refined Emerald-500
  static const Color accentRed = Color(0xFFF43F5E);    // Modern Rose-500
  static const Color accentAmber = Color(0xFFF59E0B);  // Warm Amber-500
  static const Color accentPurple = Color(0xFF8B5CF6); // Modern Violet-500

  // --- Text Contrast Hierarchy ---
  static const Color textPrimary = Color(0xFFF8FAFC);   // Slate-50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color textMuted = Color(0xFF64748B);     // Slate-500

  // --- Monospace Font Family for Technical Specs ---
  static const String monoFont = 'Consolas';

  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: accentIndigo,
        secondary: accentCyan,
        surface: cardDark,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentIndigo, width: 1.2),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          side: const BorderSide(color: borderDark, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
    );
  }
}
