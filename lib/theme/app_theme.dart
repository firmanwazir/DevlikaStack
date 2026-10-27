import 'package:flutter/material.dart';
import '../services/config_service.dart';

class AppTheme {
  // Theme state notifier (default: Light theme)
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ConfigService.instance.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
  );

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
    ConfigService.instance.setThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }

  static void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  // =========================================================================
  // LIGHT PALETTE (Clean, Modern, Soft Developer Theme - Default)
  // =========================================================================
  static const Color lightBg = Color(0xFFF1F5F9);          // Slate-100 soothing canvas
  static const Color lightSidebar = Color(0xFFFFFFFF);     // Pure white sidebar
  static const Color lightCard = Color(0xFFFFFFFF);        // Crisp white card
  static const Color lightCardHover = Color(0xFFF8FAFC);   // Slate-50 hover
  static const Color lightBorder = Color(0xFFE2E8F0);      // Slate-200 border
  static const Color lightBorderSubtle = Color(0xFFEEF2F6);// Slate-100 subtle
  static const Color lightSurfaceSubtle = Color(0xFFF8FAFC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color lightTextPrimary = Color(0xFF0F172A);   // Slate-900 (Crisp, deep, high contrast)
  static const Color lightTextSecondary = Color(0xFF334155); // Slate-700 (Clear, legible secondary)
  static const Color lightTextMuted = Color(0xFF64748B);     // Slate-500 (WCAG AA compliant, readable)

  static const Color lightAccentIndigo = Color(0xFF4F46E5); // Indigo-600
  static const Color lightAccentBlue = Color(0xFF2563EB);   // Blue-600
  static const Color lightAccentCyan = Color(0xFF0284C7);   // Sky-600
  static const Color lightAccentGreen = Color(0xFF059669);  // Emerald-600
  static const Color lightAccentRed = Color(0xFFDC2626);    // Red-600
  static const Color lightAccentAmber = Color(0xFFD97706);  // Amber-600
  static const Color lightAccentPurple = Color(0xFF7C3AED); // Violet-600

  // =========================================================================
  // DARK PALETTE (Obsidian / Zinc - Option)
  // =========================================================================
  static const Color darkBg = Color(0xFF0D0F14);
  static const Color darkSidebar = Color(0xFF11141A);
  static const Color darkCard = Color(0xFF151922);
  static const Color darkCardHover = Color(0xFF1B202B);
  static const Color darkBorder = Color(0xFF232836);
  static const Color darkBorderSubtle = Color(0xFF1D222E);
  static const Color darkSurfaceSubtle = Color(0xFF12151D);
  static const Color darkSurfaceElevated = Color(0xFF1A1F2B);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);   // Slate-50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color darkTextMuted = Color(0xFF64748B);     // Slate-500

  static const Color darkAccentIndigo = Color(0xFF6366F1); // Modern primary
  static const Color darkAccentBlue = Color(0xFF4F46E5);   // Indigo-600
  static const Color darkAccentCyan = Color(0xFF0EA5E9);   // Refined Sky-500
  static const Color darkAccentGreen = Color(0xFF10B981);  // Refined Emerald-500
  static const Color darkAccentRed = Color(0xFFF43F5E);    // Modern Rose-500
  static const Color darkAccentAmber = Color(0xFFF59E0B);  // Warm Amber-500
  static const Color darkAccentPurple = Color(0xFF8B5CF6); // Modern Violet-500

  // =========================================================================
  // ADAPTIVE GETTERS (Automatically switch based on active theme)
  // =========================================================================
  static Color get bgDark => isDarkMode ? darkBg : lightBg;
  static Color get sidebarDark => isDarkMode ? darkSidebar : lightSidebar;
  static Color get cardDark => isDarkMode ? darkCard : lightCard;
  static Color get bgCard => cardDark;
  static Color get cardHover => isDarkMode ? darkCardHover : lightCardHover;
  static Color get borderDark => isDarkMode ? darkBorder : lightBorder;
  static Color get borderSubtle => isDarkMode ? darkBorderSubtle : lightBorderSubtle;
  static Color get surfaceSubtle => isDarkMode ? darkSurfaceSubtle : lightSurfaceSubtle;
  static Color get surfaceElevated => isDarkMode ? darkSurfaceElevated : lightSurfaceElevated;

  static Color get textPrimary => isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted => isDarkMode ? darkTextMuted : lightTextMuted;

  static Color get accentIndigo => isDarkMode ? darkAccentIndigo : lightAccentIndigo;
  static Color get accentBlue => isDarkMode ? darkAccentBlue : lightAccentBlue;
  static Color get accentCyan => isDarkMode ? darkAccentCyan : lightAccentCyan;
  static Color get accentGreen => isDarkMode ? darkAccentGreen : lightAccentGreen;
  static Color get accentRed => isDarkMode ? darkAccentRed : lightAccentRed;
  static Color get accentAmber => isDarkMode ? darkAccentAmber : lightAccentAmber;
  static Color get accentPurple => isDarkMode ? darkAccentPurple : lightAccentPurple;

  // Semantic Aliases & Interactive Controls
  static Color get background => bgDark;
  static Color get card => cardDark;
  static Color get border => borderDark;
  static Color get text => textPrimary;
  static Color get navSelectedBg => isDarkMode ? const Color(0xFF1E2330) : const Color(0xFFEEF2FF);
  static Color get navSelectedBorder => isDarkMode ? const Color(0xFF2E374A) : const Color(0xFFC7D2FE);
  static Color get selectionBg => isDarkMode ? const Color(0xFF1E2330) : const Color(0xFFEEF2FF);
  static Color get selectionBorder => isDarkMode ? const Color(0xFF2E374A) : const Color(0xFFC7D2FE);
  static Color get logoBg => isDarkMode ? const Color(0xFF1E2330) : const Color(0xFFEEF2FF);
  static Color get logoBorder => isDarkMode ? const Color(0xFF2E374A) : const Color(0xFFC7D2FE);

  // Terminal & Console Log Palette
  static Color get terminalBg => isDarkMode ? const Color(0xFF090B0F) : const Color(0xFFF8FAFC);
  static Color get terminalBorder => isDarkMode ? const Color(0xFF232836) : const Color(0xFFE2E8F0);
  static Color get terminalText => isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B);

  // Adaptive Tag / Category Colors (High Contrast in both Light & Dark modes)
  static Color categoryColor(String category) {
    if (isDarkMode) {
      switch (category) {
        case 'Database': return const Color(0xFF38BDF8);
        case 'Web & API': return const Color(0xFF2DD4BF);
        case 'Media & File': return const Color(0xFFFBBF24);
        case 'Security & Crypto': return const Color(0xFF4ADE80);
        case 'Framework & Text': return const Color(0xFFA78BFA);
        case 'Performance & Debug': return const Color(0xFFFB923C);
        default: return darkAccentIndigo;
      }
    } else {
      switch (category) {
        case 'Database': return const Color(0xFF0284C7); // Sky-600
        case 'Web & API': return const Color(0xFF0D9488); // Teal-600
        case 'Media & File': return const Color(0xFFD97706); // Amber-600
        case 'Security & Crypto': return const Color(0xFF059669); // Emerald-600
        case 'Framework & Text': return const Color(0xFF7C3AED); // Purple-600
        case 'Performance & Debug': return const Color(0xFFEA580C); // Orange-600
        default: return lightAccentIndigo;
      }
    }
  }

  // Monospace Font Family
  static const String monoFont = 'Consolas';

  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textSecondary,
    );
  }

  // =========================================================================
  // LIGHT THEME (Default)
  // =========================================================================
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.light(
        primary: lightAccentIndigo,
        secondary: lightAccentCyan,
        surface: lightCard,
        error: lightAccentRed,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextPrimary),
        bodySmall: TextStyle(color: lightTextSecondary),
        labelLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: lightTextSecondary),
        labelSmall: TextStyle(color: lightTextMuted),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        textStyle: const TextStyle(color: lightTextPrimary, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightAccentIndigo, width: 1.2),
        ),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: lightAccentIndigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
    );
  }

  // =========================================================================
  // DARK THEME (Option)
  // =========================================================================
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: darkAccentIndigo,
        secondary: darkAccentCyan,
        surface: darkCard,
        error: darkAccentRed,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkAccentIndigo, width: 1.2),
        ),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: darkAccentIndigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
    );
  }
}
