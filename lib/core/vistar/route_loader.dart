import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Full-canvas dim overlay with a breathing S mark in the center.
/// Show for ~360ms on every route change to mask layout jank.
class RouteLoader extends StatefulWidget {
  const RouteLoader({super.key, this.visible = true});

  final bool visible;

  @override
  State<RouteLoader> createState() => _RouteLoaderState();
}

class _RouteLoaderState extends State<RouteLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Vistar.bg.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) {
            // 0.92 .. 1.04 breathing scale, matching the splash orbit feel.
            final scale = 0.92 + (_ctl.value * 0.12);
            return Transform.scale(
              scale: scale,
              child: const SizedBox(
                width: 64,
                height: 65,
                child: Image(
                  image: AssetImage(Vistar.smarkAsset),
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
