import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vistar.dart';

/// Vistar Premium ThemeData factories.
///
/// Dark is the canonical theme; the light variant is a best-effort adaptation
/// (the spec is dark-only) that keeps Bricolage/Manrope typography and the
/// ribbon as the signature accent.
class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(isDark);
    final textTheme = _textTheme(isDark);

    final fg = isDark ? Vistar.txt : Vistar.lightTxt;
    final fg2 = isDark ? Vistar.txt2 : Vistar.lightTxt2;
    final fg3 = isDark ? Vistar.txt3 : Vistar.lightTxt3;
    final bg = isDark ? Vistar.bg : Vistar.lightBg;
    final surface = isDark ? Vistar.surface : Vistar.lightSurface;
    final line = isDark ? Vistar.line : Vistar.lightLine;
    final line2 = isDark ? Vistar.line2 : Vistar.lightLine2;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: line,
      hintColor: fg3,
      iconTheme: IconThemeData(color: fg2),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Vistar.pink),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          color: fg,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Vistar.r),
          side: BorderSide(color: line, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Vistar.pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Vistar.rSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: line2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Vistar.rSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Vistar.pink,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: fg3),
        labelStyle: TextStyle(color: fg2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          borderSide: const BorderSide(color: Vistar.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          borderSide: const BorderSide(color: Vistar.bad),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          borderSide: const BorderSide(color: Vistar.bad, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? Vistar.surface2 : Vistar.lightSurface2,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.1,
          color: fg2,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Vistar.pink,
        unselectedLabelColor: fg2,
        indicatorColor: Vistar.pink,
        dividerColor: line,
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? Vistar.surface2 : Vistar.lightSurface2,
        contentTextStyle: GoogleFonts.manrope(color: fg, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Vistar.rSm),
          side: BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Vistar.r),
          side: BorderSide(color: line),
        ),
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          color: fg,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        contentTextStyle: GoogleFonts.manrope(color: fg2, fontSize: 14),
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final base = (isDark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true))
        .textTheme;

    // Manrope for everything by default; Bricolage Grotesque overrides on
    // display/headline/title-large (per spec: -0.4 letter-spacing, weight 700–800).
    final body = GoogleFonts.manropeTextTheme(base);

    TextStyle bricolage(TextStyle? from, {required FontWeight weight}) =>
        GoogleFonts.bricolageGrotesque(
          textStyle: from,
          fontWeight: weight,
          letterSpacing: -0.4,
        );

    return body.copyWith(
      displayLarge: bricolage(base.displayLarge, weight: FontWeight.w800),
      displayMedium: bricolage(base.displayMedium, weight: FontWeight.w800),
      displaySmall: bricolage(base.displaySmall, weight: FontWeight.w800),
      headlineLarge: bricolage(base.headlineLarge, weight: FontWeight.w800),
      headlineMedium: bricolage(base.headlineMedium, weight: FontWeight.w800),
      headlineSmall: bricolage(base.headlineSmall, weight: FontWeight.w700),
      titleLarge: bricolage(base.titleLarge, weight: FontWeight.w700),
    );
  }

  static ColorScheme _scheme(bool isDark) {
    if (isDark) {
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Vistar.pink,
        onPrimary: Colors.white,
        secondary: Vistar.violet,
        onSecondary: Colors.white,
        tertiary: Vistar.orange,
        onTertiary: Colors.white,
        error: Vistar.bad,
        onError: Colors.white,
        surface: Vistar.surface,
        onSurface: Vistar.txt,
        surfaceContainerLowest: Vistar.bg,
        surfaceContainerLow: Vistar.bg2,
        surfaceContainer: Vistar.surface,
        surfaceContainerHigh: Vistar.surface2,
        surfaceContainerHighest: Vistar.surface3,
        onSurfaceVariant: Vistar.txt2,
        outline: Vistar.line,
        outlineVariant: Vistar.line2,
      );
    }
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Vistar.pink,
      onPrimary: Colors.white,
      secondary: Vistar.violet,
      onSecondary: Colors.white,
      tertiary: Vistar.orange,
      onTertiary: Colors.white,
      error: Vistar.bad,
      onError: Colors.white,
      surface: Vistar.lightSurface,
      onSurface: Vistar.lightTxt,
      surfaceContainerLowest: Vistar.lightBg2,
      surfaceContainerLow: Vistar.lightBg,
      surfaceContainer: Vistar.lightSurface,
      surfaceContainerHigh: Vistar.lightSurface2,
      surfaceContainerHighest: Vistar.lightSurface3,
      onSurfaceVariant: Vistar.lightTxt2,
      outline: Vistar.lightLine,
      outlineVariant: Vistar.lightLine2,
    );
  }
}
