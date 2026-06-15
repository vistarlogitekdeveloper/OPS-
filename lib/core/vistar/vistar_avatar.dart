import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/vistar.dart';

/// Rounded-square avatar with ribbon gradient (or muted) background and
/// Bricolage initials in white.
class VistarAvatar extends StatelessWidget {
  const VistarAvatar({
    super.key,
    required this.label,
    this.size = 38,
    this.gradient = true,
  });

  final String label;
  final double size;
  final bool gradient;

  String get _initials {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient ? Vistar.ribbon : null,
        color: gradient ? null : Vistar.surface2,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        _initials,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
