import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Primary CTA with the rainbow ribbon gradient and a pink glow drop-shadow.
/// The signature button of the Vistar system — use sparingly, with intent.
class RibbonButton extends StatelessWidget {
  const RibbonButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.small = false,
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool small;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final radius = small ? 10.0 : Vistar.rSm;
    final pad = small
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 13);

    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              gradient: disabled
                  ? LinearGradient(colors: [
                      Vistar.txt3.withValues(alpha: 0.35),
                      Vistar.txt3.withValues(alpha: 0.35),
                    ])
                  : Vistar.ribbon,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: Vistar.pink.withValues(alpha: 0.7),
                        blurRadius: 34,
                        spreadRadius: -14,
                        offset: const Offset(0, 14),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: small ? 16 : 18, color: Colors.white),
                  const SizedBox(width: 9),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: small ? 13 : 14,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
