import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Vistar card surface: 1px hairline, vertical surface gradient, optional
/// corner-S accent, optional glow-lift on mouse hover (desktop/web).
class VistarCard extends StatefulWidget {
  const VistarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.cornerS = false,
    this.glow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool cornerS;
  final bool glow;
  final VoidCallback? onTap;

  @override
  State<VistarCard> createState() => _VistarCardState();
}

class _VistarCardState extends State<VistarCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverActive = _hover && widget.glow;

    final line = hoverActive
        ? (isDark ? Vistar.line2 : Vistar.lightLine2)
        : (isDark ? Vistar.line : Vistar.lightLine);

    final topFill = isDark
        ? Vistar.surface2.withValues(alpha: 0.7)
        : Vistar.lightSurface.withValues(alpha: 0.92);
    final btmFill = isDark
        ? Vistar.surface.withValues(alpha: 0.7)
        : Vistar.lightSurface2.withValues(alpha: 0.92);

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: hoverActive
          ? Matrix4.translationValues(0.0, -2.0, 0.0)
          : Matrix4.identity(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topFill, btmFill],
        ),
        borderRadius: BorderRadius.circular(Vistar.r),
        border: Border.all(color: line, width: 1),
        boxShadow: hoverActive
            ? [
                BoxShadow(
                  color: Vistar.magenta.withValues(alpha: 0.4),
                  blurRadius: 50,
                  spreadRadius: -22,
                  offset: const Offset(0, 18),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Vistar.r),
        child: Stack(
          children: [
            if (widget.cornerS)
              const Positioned(
                right: -26,
                bottom: -30,
                width: 120,
                height: 120,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.05,
                    child: Image(
                      image: AssetImage(Vistar.smarkAsset),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(Vistar.r),
          child: card,
        ),
      );
    }
    if (widget.glow) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: card,
      );
    }
    return card;
  }
}
