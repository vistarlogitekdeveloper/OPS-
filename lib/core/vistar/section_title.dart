import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Small section header with a 5×16 ribbon-gradient accent bar to the left.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 16,
            decoration: BoxDecoration(
              gradient: Vistar.ribbon,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
