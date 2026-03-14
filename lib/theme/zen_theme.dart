import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colour palette ─────────────────────────────────────────────────────────

class ZenColors {
  // Core palette
  static const Color sand = Color(0xFFF6F1E7);
  static const Color clay = Color(0xFFDAB892);
  static const Color sage = Color(0xFF6E8B74);
  static const Color forest = Color(0xFF3F5A45);
  static const Color earth = Color(0xFF7A5C44);
  static const Color bark = Color(0xFF2D3A2E);
  static const Color mist = Color(0xFFF9F7F2);
  static const Color card = Color(0xFFFDF9F2);

  // Extended tonal range
  static const Color sage100 = Color(0xFFE8F0EA);
  static const Color sage200 = Color(0xFFC4D6C8);
  static const Color teal = Color(0xFF4A9B8E);
  static const Color teal100 = Color(0xFFDFF3F0);
  static const Color teal200 = Color(0xFFB2E0DA);
  static const Color deepGreen = Color(0xFF2C4A32);

  // Surface tiers
  static const Color surface0 = Color(0xFFF9F6EF);  // page bg
  static const Color surface1 = Color(0xFFFEFCF7);  // card bg
  static const Color surface2 = Color(0xFFEEE9DE);  // subtle divider

  // Semantic
  static const Color success = Color(0xFF3D8B68);
  static const Color successLight = Color(0xFFD6EFE4);
  static const Color warning = Color(0xFFD4872A);
  static const Color warningLight = Color(0xFFFAEDD5);
  static const Color error = Color(0xFFB33A3A);
  static const Color errorLight = Color(0xFFFAD5D5);

  // Text hierarchy
  static const Color textPrimary = Color(0xFF1E2A20);
  static const Color textSecondary = Color(0xFF5C6E5F);
  static const Color textMuted = Color(0xFF8FA090);
}

// ── Spacing constants ───────────────────────────────────────────────────────

class ZenSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 0, 20, 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(18);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(14);
}

// ── Decoration helpers ──────────────────────────────────────────────────────

class ZenDecor {
  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(20));
  static const BorderRadius pillRadius =
      BorderRadius.all(Radius.circular(999));
  static const BorderRadius chipRadius =
      BorderRadius.all(Radius.circular(10));

  static BoxDecoration gradientBackdrop() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFF5EEE0),
          Color(0xFFE9DDD0),
          Color(0xFFDCC9AE),
        ],
        stops: [0.0, 0.55, 1.0],
      ),
    );
  }

  static BoxDecoration heroGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          ZenColors.forest,
          ZenColors.teal,
        ],
      ),
      borderRadius: cardRadius,
    );
  }

  static BoxDecoration accentCard({Color? color}) {
    return BoxDecoration(
      color: color ?? ZenColors.teal100,
      borderRadius: cardRadius,
    );
  }

  static BoxDecoration softCard({
    Color color = ZenColors.surface1,
    double elevation = 0.12,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: cardRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ZenColors.earth.withValues(alpha: elevation),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration elevatedCard({Color color = ZenColors.surface1}) {
    return BoxDecoration(
      color: color,
      borderRadius: cardRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ZenColors.bark.withValues(alpha: 0.10),
          blurRadius: 32,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: ZenColors.bark.withValues(alpha: 0.05),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration glassMorphism() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: cardRadius,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1,
      ),
    );
  }
}

// ── Theme builder ───────────────────────────────────────────────────────────

class ZenTheme {
  static ThemeData build() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ZenColors.sage,
      onPrimary: Colors.white,
      primaryContainer: ZenColors.sage100,
      onPrimaryContainer: ZenColors.forest,
      secondary: ZenColors.teal,
      onSecondary: Colors.white,
      secondaryContainer: ZenColors.teal100,
      onSecondaryContainer: ZenColors.teal,
      tertiary: ZenColors.clay,
      onTertiary: ZenColors.bark,
      error: ZenColors.error,
      onError: Colors.white,
      surface: ZenColors.surface0,
      onSurface: ZenColors.textPrimary,
      surfaceContainerHighest: ZenColors.surface2,
      outline: ZenColors.sage200,
    );

    final baseTextTheme = GoogleFonts.manropeTextTheme();
    final headingFont = GoogleFonts.cormorantGaramond(
      fontWeight: FontWeight.w700,
      color: ZenColors.textPrimary,
    );
    final bodyFont = GoogleFonts.manrope(color: ZenColors.textPrimary);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ZenColors.surface0,
      useMaterial3: true,
      textTheme: baseTextTheme.copyWith(
        displayLarge: headingFont.copyWith(fontSize: 48, height: 1.1),
        displayMedium: headingFont.copyWith(fontSize: 40, height: 1.1),
        headlineLarge: headingFont.copyWith(fontSize: 34, height: 1.15),
        headlineMedium: headingFont.copyWith(fontSize: 28, height: 1.2),
        headlineSmall: headingFont.copyWith(fontSize: 22, height: 1.25),
        titleLarge: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ZenColors.textPrimary,
          height: 1.2,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ZenColors.textPrimary,
        ),
        titleSmall: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ZenColors.textPrimary,
        ),
        bodyLarge: bodyFont.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: bodyFont.copyWith(
          fontSize: 14,
          height: 1.5,
          color: ZenColors.textSecondary,
        ),
        bodySmall: bodyFont.copyWith(
          fontSize: 12,
          height: 1.4,
          color: ZenColors.textMuted,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ZenColors.textPrimary,
        ),
        labelMedium: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ZenColors.textSecondary,
        ),
        labelSmall: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ZenColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ZenColors.surface0,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ZenColors.textPrimary,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: ZenColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: ZenColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ZenDecor.cardRadius,
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZenColors.surface1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: ZenColors.sage200.withValues(alpha: 0.7),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: ZenColors.sage200.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZenColors.sage, width: 1.8),
        ),
        hintStyle: GoogleFonts.manrope(
          color: ZenColors.textMuted,
          fontSize: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ZenColors.forest,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ZenColors.forest,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ZenColors.sage200,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZenColors.forest,
          side: const BorderSide(color: ZenColors.sage, width: 1.5),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZenColors.surface1,
        indicatorColor: ZenColors.sage100,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ZenColors.forest,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ZenColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ZenColors.forest, size: 24);
          }
          return const IconThemeData(color: ZenColors.textMuted, size: 24);
        }),
        elevation: 0,
        height: 68,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ZenColors.sage100,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ZenColors.forest,
        ),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: ZenDecor.chipRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: ZenColors.surface2,
        thickness: 1,
        space: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZenColors.teal,
        linearTrackColor: ZenColors.surface2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZenColors.bark,
        contentTextStyle: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
