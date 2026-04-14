import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color primaryPink = Color(0xFFFF6B9D);
  static const Color accentCyan = Color(0xFF00D4AA);
  static const Color accentOrange = Color(0xFFFF8A50);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0D0D1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkElevated = Color(0xFF222244);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentCyan, Color(0xFF00B4D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBg, Color(0xFF1A0A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E3F), Color(0xFF2D2D5F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: primaryPink,
        tertiary: accentCyan,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withAlpha(20), width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        inactiveTrackColor: darkElevated,
        thumbColor: primaryPurple,
        overlayColor: primaryPurple.withAlpha(40),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        secondary: primaryPink,
        tertiary: accentCyan,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black54),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black54),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[100],
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withAlpha(20), width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black54),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryPurple,
        unselectedItemColor: Colors.black38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        inactiveTrackColor: Colors.grey[300],
        thumbColor: primaryPurple,
        overlayColor: primaryPurple.withAlpha(40),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
    );
  }

  static ThemeData get amoledTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: primaryPink,
        tertiary: accentCyan,
        surface: Colors.black,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: darkTheme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF080808),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      elevatedButtonTheme: darkTheme.elevatedButtonTheme,
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111111),
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF333333), width: 1.5),
        ),
      ),
      outlinedButtonTheme: darkTheme.outlinedButtonTheme,
      iconTheme: const IconThemeData(color: Colors.white70),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: primaryPurple,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: darkTheme.sliderTheme,
    );
  }

  static ThemeData get midnightTheme {
    const midnightBg = Color(0xFF070B19);
    const midnightSurface = Color(0xFF0D1126);
    const midnightCard = Color(0xFF11182A);
    const midnightElevated = Color(0xFF1A233A);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: midnightBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: primaryPink,
        tertiary: accentCyan,
        surface: midnightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: darkTheme.textTheme,
      appBarTheme: darkTheme.appBarTheme,
      cardTheme: CardThemeData(
        color: midnightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: darkTheme.elevatedButtonTheme,
      dialogTheme: DialogThemeData(
        backgroundColor: midnightSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withAlpha(20), width: 1.5),
        ),
      ),
      outlinedButtonTheme: darkTheme.outlinedButtonTheme,
      iconTheme: darkTheme.iconTheme,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: midnightSurface,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: darkTheme.sliderTheme,
    );
  }

  static LinearGradient? getBackgroundGradient(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) return null;
    if (theme.scaffoldBackgroundColor == Colors.black) return null; // AMOLED
    if (theme.scaffoldBackgroundColor == const Color(0xFF070B19)) {
      return const LinearGradient(
        colors: [Color(0xFF070B19), Color(0xFF0D1126)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return darkGradient;
  }

  static Color getCardColor(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) return Colors.grey[100]!;
    if (Theme.of(context).scaffoldBackgroundColor == Colors.black) return const Color(0xFF080808);
    if (Theme.of(context).scaffoldBackgroundColor == const Color(0xFF070B19)) return const Color(0xFF11182A);
    return darkCard;
  }

  static Color getElevatedColor(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) return Colors.grey[200]!;
    if (Theme.of(context).scaffoldBackgroundColor == Colors.black) return const Color(0xFF111111);
    if (Theme.of(context).scaffoldBackgroundColor == const Color(0xFF070B19)) return const Color(0xFF1A233A);
    return darkElevated;
  }

  // Helper to create gradient decoration
  static BoxDecoration gradientBox({
    LinearGradient? gradient,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      gradient: gradient ?? primaryGradient,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration glassBox({double borderRadius = 16, double opacity = 0.1}) {
    return BoxDecoration(
      color: Colors.white.withAlpha((opacity * 255).toInt()),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withAlpha(25),
        width: 1,
      ),
    );
  }
}
