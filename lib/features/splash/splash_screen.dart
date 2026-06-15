import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/vistar.dart';

/// Vistar startup splash — auto-dismisses after ~2.2s. Show once on app boot,
/// then hand off to the actual routed content.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spinR1 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  late final AnimationController _spinR2 = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _spinR1.dispose();
    _spinR2.dispose();
    _breathe.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Vistar.bg : Vistar.lightBg;
    final hint = isDark ? Vistar.txt3 : Vistar.lightTxt3;

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Centered radial brand glow
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Vistar.pink.withValues(alpha: isDark ? 0.18 : 0.10),
                  Vistar.purple.withValues(alpha: isDark ? 0.12 : 0.06),
                  bg.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OrbitLoader(spinR1: _spinR1, spinR2: _spinR2, breathe: _breathe),
                const SizedBox(height: 36),
                Image.asset(
                  Vistar.wordmarkAsset,
                  height: 52,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'OPERATIONAL EXCELLENCE COMPLIANCE',
                  style: TextStyle(
                    color: hint,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 30),
                _RibbonProgressBar(bar: _bar, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitLoader extends StatelessWidget {
  const _OrbitLoader({
    required this.spinR1,
    required this.spinR2,
    required this.breathe,
  });
  final AnimationController spinR1;
  final AnimationController spinR2;
  final AnimationController breathe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring (pink/orange, clockwise)
          AnimatedBuilder(
            animation: spinR1,
            builder: (_, _) => Transform.rotate(
              angle: spinR1.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _RingPainter(
                  topColor: Vistar.pink.withValues(alpha: 0.65),
                  rightColor: Vistar.orange.withValues(alpha: 0.40),
                ),
              ),
            ),
          ),
          // Inner ring (violet/amber, counter-clockwise)
          AnimatedBuilder(
            animation: spinR2,
            builder: (_, _) => Transform.rotate(
              angle: -spinR2.value * 2 * math.pi,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: CustomPaint(
                  size: const Size(156, 156),
                  painter: _RingPainter(
                    bottomColor: Vistar.purple.withValues(alpha: 0.65),
                    leftColor: Vistar.amber.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
          // Breathing S mark + pink halo (simulates the drop-shadow glow)
          AnimatedBuilder(
            animation: breathe,
            builder: (_, _) {
              final scale = 0.92 + (breathe.value * 0.12);
              return Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Vistar.pink.withValues(alpha: 0.55),
                              Vistar.pink.withValues(alpha: 0.0),
                            ],
                            stops: const [0.3, 1.0],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        height: 97,
                        child: Image.asset(
                          Vistar.smarkAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RibbonProgressBar extends StatelessWidget {
  const _RibbonProgressBar({required this.bar, required this.isDark});
  final AnimationController bar;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final trackColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.07);
    return SizedBox(
      width: 200,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor),
            AnimatedBuilder(
              animation: bar,
              builder: (_, _) {
                // Slide a 40%-wide ribbon segment across the track.
                final t = bar.value;
                return FractionalTranslation(
                  translation: Offset(-1.1 + t * 4.7, 0),
                  child: const FractionallySizedBox(
                    widthFactor: 0.4,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: Vistar.ribbon),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    this.topColor,
    this.rightColor,
    this.bottomColor,
    this.leftColor,
  });
  final Color? topColor;
  final Color? rightColor;
  final Color? bottomColor;
  final Color? leftColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide / 2) - 0.75,
    );
    const quarter = math.pi / 2;
    void arc(double start, Color? c) {
      if (c == null) return;
      paint.color = c;
      canvas.drawArc(rect, start, quarter, false, paint);
    }

    arc(-math.pi * 3 / 4, topColor);
    arc(-math.pi / 4, rightColor);
    arc(math.pi / 4, bottomColor);
    arc(math.pi * 3 / 4, leftColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      topColor != old.topColor ||
      rightColor != old.rightColor ||
      bottomColor != old.bottomColor ||
      leftColor != old.leftColor;
}

/// Wraps any [child] so the splash shows on first build for ~2.2s, then
/// cross-fades to the child. Mount once at the top of the app tree.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _done
          ? KeyedSubtree(
              key: const ValueKey('content'),
              child: widget.child,
            )
          : const KeyedSubtree(
              key: ValueKey('splash'),
              child: SplashScreen(),
            ),
    );
  }
}
