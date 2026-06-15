import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Animated rainbow-tinted shimmer placeholder. Use while data loads.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 10,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Vistar.surface2 : Vistar.lightSurface2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            // Sweep enters at -1, exits at 2 (one full pass per cycle).
            final t = _ctl.value * 3 - 1;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: base),
                FractionalTranslation(
                  translation: Offset(t, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Vistar.pink.withValues(alpha: 0.16),
                          Vistar.orange.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
