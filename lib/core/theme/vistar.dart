import 'package:flutter/material.dart';

/// Vistar Premium design-system tokens.
///
/// One source of truth for the rainbow ribbon, dark/light surfaces,
/// hairlines, status colors, radii, and brand asset paths. The ribbon
/// gradient is the signature accent — use sparingly (primary buttons,
/// active-nav bars, section accents, KPI numbers).
class Vistar {
  Vistar._();

  // ── Brand ribbon palette ───────────────────────────────────────────
  static const Color purple = Color(0xFF7A1FB0);
  static const Color violet = Color(0xFF9B30C9);
  static const Color magenta = Color(0xFFC018C0);
  static const Color pink = Color(0xFFE0218A);
  static const Color red = Color(0xFFC8102E);
  static const Color orangeRed = Color(0xFFF0480C);
  static const Color orange = Color(0xFFF06000);
  static const Color amber = Color(0xFFF0C000);
  static const Color yellow = Color(0xFFF0E060);
  static const Color cream = Color(0xFFFFF6CC);

  // ── Dark surfaces (the canonical Vistar theme) ─────────────────────
  static const Color bg = Color(0xFF070611);
  static const Color bg2 = Color(0xFF0B0A18);
  static const Color surface = Color(0xFF110F1E);
  static const Color surface2 = Color(0xFF16142A);
  static const Color surface3 = Color(0xFF1D1A33);
  static const Color txt = Color(0xFFF2EEFB);
  static const Color txt2 = Color(0xFFB9B2D6);
  static const Color txt3 = Color(0xFF7E769B);
  static const Color line = Color(0x14FFFFFF);
  static const Color line2 = Color(0x21FFFFFF);

  // ── Light surfaces (Vistar-flavored adaptation; ribbon still pops) ─
  static const Color lightBg = Color(0xFFF7F5FB);
  static const Color lightBg2 = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1ECF7);
  static const Color lightSurface3 = Color(0xFFE6DFF1);
  static const Color lightTxt = Color(0xFF1B1530);
  static const Color lightTxt2 = Color(0xFF55456F);
  static const Color lightTxt3 = Color(0xFF887AA4);
  static const Color lightLine = Color(0x141B1530);
  static const Color lightLine2 = Color(0x261B1530);

  // ── Status ─────────────────────────────────────────────────────────
  static const Color ok = Color(0xFF34D399);
  static const Color warn = Color(0xFFFBBF24);
  static const Color bad = Color(0xFFFB6F84);
  static const Color info = Color(0xFF5BA8FF);

  // ── Radii ──────────────────────────────────────────────────────────
  static const double rSm = 11;
  static const double r = 16;
  static const double rLg = 22;

  // ── Signature rainbow ribbon (115deg) ──────────────────────────────
  static const LinearGradient ribbon = LinearGradient(
    begin: Alignment(-1, -0.5),
    end: Alignment(1, 0.5),
    stops: [0.00, 0.22, 0.40, 0.56, 0.70, 0.80, 0.92, 1.00],
    colors: [
      Color(0xFF7A1FB0),
      Color(0xFFB81FB8),
      Color(0xFFE0218A),
      Color(0xFFD11630),
      Color(0xFFF0480C),
      Color(0xFFF06000),
      Color(0xFFF0C000),
      Color(0xFFF7EE9A),
    ],
  );

  static const LinearGradient ribbonSoft = LinearGradient(
    begin: Alignment(-1, -0.5),
    end: Alignment(1, 0.5),
    colors: [
      Color(0xE69B30C9),
      Color(0xE6E0218A),
      Color(0xE6F0480C),
      Color(0xE6F0C000),
    ],
  );

  // ── Shadows / glow ─────────────────────────────────────────────────
  static const BoxShadow shadow = BoxShadow(
    color: Color(0xD9000000),
    blurRadius: 60,
    spreadRadius: -28,
    offset: Offset(0, 24),
  );

  static const BoxShadow glow = BoxShadow(
    color: Color(0x66C018C0),
    blurRadius: 50,
    spreadRadius: -22,
    offset: Offset(0, 18),
  );

  // ── Brand asset paths ──────────────────────────────────────────────
  // Drop these files into app/assets/brand/ before Phase 3.
  static const String smarkAsset = 'assets/brand/logo.png';
  static const String wordmarkAsset = 'assets/brand/logo_name.png';
}
