import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Full-canvas Vistar backdrop: three radial brand glows + a faint S
/// watermark drifting off the right edge. Place at the bottom of a Stack
/// and float real content above it.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Vistar.bg : Vistar.lightBg;

    // Glows are softer in light mode so the canvas stays calm.
    final mul = isDark ? 1.0 : 0.55;
    final shortest = MediaQuery.sizeOf(context).shortestSide;

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Glow(
            alignment: const Alignment(-0.76, -1.18),
            color: Vistar.purple.withValues(alpha: 0.22 * mul),
            size: const Size(800, 600),
          ),
          _Glow(
            alignment: const Alignment(1.10, -0.84),
            color: Vistar.pink.withValues(alpha: 0.16 * mul),
            size: const Size(700, 600),
          ),
          _Glow(
            alignment: const Alignment(0.60, 1.20),
            color: Vistar.orange.withValues(alpha: 0.12 * mul),
            size: const Size(900, 700),
          ),
          IgnorePointer(
            child: Align(
              alignment: const Alignment(1.6, 0),
              child: Transform.rotate(
                angle: 4 * math.pi / 180,
                child: Opacity(
                  opacity: isDark ? 0.05 : 0.04,
                  child: Image.asset(
                    Vistar.smarkAsset,
                    width: shortest * 1.4,
                    height: shortest * 1.4,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Subtle grain to break up the smooth gradients (mix-blend feel).
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GrainPainter(
                  color: isDark ? Colors.white : Colors.black,
                  opacity: 0.045,
                ),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Deterministic noise overlay — tiny semi-transparent dots scattered with a
/// fixed seed so the pattern doesn't flicker between rebuilds.
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.color, this.opacity = 0.045});
  final Color color;
  final double opacity;

  static const _seed = 0x715A;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rng = math.Random(_seed);
    final paint = Paint()..color = color.withValues(alpha: opacity);
    final count = (size.width * size.height / 900).round().clamp(200, 4000);
    final points = <Offset>[
      for (int i = 0; i < count; i++)
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
    ];
    canvas.drawPoints(ui.PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.color != color || old.opacity != opacity;
}

class _Glow extends StatelessWidget {
  const _Glow({required this.alignment, required this.color, required this.size});

  final Alignment alignment;
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
