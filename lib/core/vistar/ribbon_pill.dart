import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Status pill kinds — map to translucent tint + colored dot/label.
enum PillKind { info, amber, violet, pink, ok, orange, bad, neutral }

/// Translucent status pill with colored dot and bold label.
class RibbonPill extends StatelessWidget {
  const RibbonPill({super.key, required this.label, this.kind = PillKind.neutral});

  final String label;
  final PillKind kind;

  static (Color bg, Color dot) _palette(PillKind k) {
    switch (k) {
      case PillKind.info:
        return (Vistar.info.withValues(alpha: 0.14), Vistar.info);
      case PillKind.amber:
        return (Vistar.amber.withValues(alpha: 0.14), Vistar.amber);
      case PillKind.violet:
        return (Vistar.violet.withValues(alpha: 0.18), Vistar.violet);
      case PillKind.pink:
        return (Vistar.pink.withValues(alpha: 0.16), Vistar.pink);
      case PillKind.ok:
        return (Vistar.ok.withValues(alpha: 0.14), Vistar.ok);
      case PillKind.orange:
        return (Vistar.orange.withValues(alpha: 0.16), Vistar.orange);
      case PillKind.bad:
        return (Vistar.bad.withValues(alpha: 0.14), Vistar.bad);
      case PillKind.neutral:
        return (const Color(0x12FFFFFF), Vistar.txt2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, dot) = _palette(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0.1,
              color: dot,
            ),
          ),
        ],
      ),
    );
  }
}
