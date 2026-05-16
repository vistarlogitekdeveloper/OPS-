import 'package:flutter/material.dart';

import '../../data/dashboard_models.dart';

class ComplianceHeatmap extends StatelessWidget {
  const ComplianceHeatmap({super.key, required this.grid});
  final ComplianceGrid grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (grid.projects.isEmpty || grid.months.isEmpty) {
      return Center(child: Text('No data.', style: theme.textTheme.bodyMedium));
    }
    const labelW = 96.0;
    const cellW = 56.0;
    const cellH = 32.0;
    final tableW = labelW + grid.months.length * cellW;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: tableW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — months
              Row(
                children: [
                  const SizedBox(width: labelW),
                  for (final m in grid.months)
                    SizedBox(
                      width: cellW,
                      child: Center(
                        child: Text(
                          _shortMonth(m),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Body rows
              for (final p in grid.projects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelW,
                        child: Text(p.code,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
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
              const SizedBox(height: 8),
              _Legend(),
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
    final scheme = Theme.of(context).colorScheme;
    final pct = percent ?? -1;
    final (bg, fg) = switch (pct) {
      < 0 => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      0 => (scheme.errorContainer, scheme.onErrorContainer),
      < 50 => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      < 100 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Tooltip(
      message: status == null
          ? 'No submission'
          : 'Status: $status\nApproved items: ${percent ?? 0}%',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          percent == null ? '—' : '$percent%',
          style: TextStyle(color: fg, fontSize: 12),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    Widget swatch(Color c, String label) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    return Wrap(
      children: [
        swatch(scheme.surfaceContainerHighest, 'No submission'),
        swatch(scheme.errorContainer, '0%'),
        swatch(scheme.tertiaryContainer, '<50%'),
        swatch(scheme.secondaryContainer, '50–99%'),
        swatch(scheme.primaryContainer, '100%'),
      ],
    );
  }
}
