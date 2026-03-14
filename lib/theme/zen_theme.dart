import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenColors {
  static const Color sand = Color(0xFFF6F1E7);
  static const Color clay = Color(0xFFDAB892);
  static const Color sage = Color(0xFF6E8B74);
  static const Color forest = Color(0xFF3F5A45);
  static const Color earth = Color(0xFF7A5C44);
  static const Color bark = Color(0xFF2D3A2E);
  static const Color mist = Color(0xFFF9F7F2);
  static const Color card = Color(0xFFFDF9F2);
}

class ZenTheme {
  static ThemeData build() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ZenColors.sage,
      onPrimary: Colors.white,
      secondary: ZenColors.clay,
      onSecondary: ZenColors.bark,
      error: const Color(0xFFB33A3A),
      onError: Colors.white,
      surface: ZenColors.sand,
      onSurface: ZenColors.bark,
    );

    final baseTextTheme = GoogleFonts.manropeTextTheme();
    final headingStyle = GoogleFonts.cormorantGaramond(
      fontWeight: FontWeight.w700,
      color: ZenColors.bark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ZenColors.sand,
      useMaterial3: true,
      textTheme: baseTextTheme.copyWith(
        headlineLarge: headingStyle.copyWith(fontSize: 36),
        headlineMedium: headingStyle.copyWith(fontSize: 28),
        titleLarge: headingStyle.copyWith(fontSize: 24),
        titleMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ZenColors.bark,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          height: 1.35,
          color: ZenColors.bark,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.35,
          color: ZenColors.bark,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ZenColors.sand,
        elevation: 0,
        centerTitle: true,
        foregroundColor: ZenColors.bark,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: ZenColors.bark,
        ),
      ),
      cardTheme: CardThemeData(
        color: ZenColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ZenColors.clay.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ZenColors.clay.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ZenColors.sage, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ZenColors.sage,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ZenColors.forest,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class ZenDecor {
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));

  static BoxDecoration gradientBackdrop() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFF5EEE0),
          Color(0xFFE5D5BF),
          Color(0xFFDCC9AE),
        ],
      ),
    );
  }

  static BoxDecoration softCard({
    Color color = ZenColors.card,
    double elevation = 0.14,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: cardRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ZenColors.earth.withValues(alpha: elevation),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
