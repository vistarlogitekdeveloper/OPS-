import 'package:flutter/material.dart';

import '../../../../core/theme/vistar.dart';
import '../../data/dashboard_models.dart';

class ComplianceHeatmap extends StatelessWidget {
  const ComplianceHeatmap({super.key, required this.grid});
  final ComplianceGrid grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (grid.projects.isEmpty || grid.months.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No data.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    const labelW = 96.0;
    const cellW = 56.0;
    const cellH = 32.0;
    final tableW = labelW + grid.months.length * cellW;
    final monthLabelStyle = TextStyle(
      color: theme.hintColor,
      fontSize: 10.5,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
    );
    final rowLabelStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: tableW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: labelW),
                  for (final m in grid.months)
                    SizedBox(
                      width: cellW,
                      child: Center(
                        child: Text(_shortMonth(m), style: monthLabelStyle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final p in grid.projects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelW,
                        child: Text(
                          p.code,
                          style: rowLabelStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final cell in p.cells)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: _Cell(
                            percent: cell.percent,
                            status: cell.status,
                            width: cellW - 4,
                            height: cellH,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortMonth(String m) =>
      m.length >= 7 ? '${m.substring(2, 4)}-${m.substring(5, 7)}' : m;
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.percent,
    required this.status,
    required this.width,
    required this.height,
  });
  final int? percent;
  final String? status;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pct = percent ?? -1;
    final (bg, fg) = _palette(pct);
    return Tooltip(
      message: status == null
          ? 'No submission'
          : 'Status: $status\nApproved items: ${percent ?? 0}%',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          percent == null ? '—' : '$percent%',
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static (Color, Color) _palette(int pct) {
    if (pct < 0) return (const Color(0x14FFFFFF), Vistar.txt3);
    if (pct == 0) return (Vistar.bad.withValues(alpha: 0.20), Vistar.bad);
    if (pct < 50) return (Vistar.orange.withValues(alpha: 0.22), Vistar.orange);
    if (pct < 100) return (Vistar.amber.withValues(alpha: 0.22), Vistar.amber);
    return (Vistar.ok.withValues(alpha: 0.22), Vistar.ok);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget swatch(Color c, String label) => Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    return Wrap(
      children: [
        swatch(Vistar.txt3, 'No submission'),
        swatch(Vistar.bad, '0%'),
        swatch(Vistar.orange, '<50%'),
        swatch(Vistar.amber, '50–99%'),
        swatch(Vistar.ok, '100%'),
      ],
    );
  }
}
