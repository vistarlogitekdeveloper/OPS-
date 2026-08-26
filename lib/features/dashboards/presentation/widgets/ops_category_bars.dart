import 'package:flutter/material.dart';

import '../../../../core/theme/vistar.dart';
import '../../data/ops_summary_models.dart';

/// Fleet attainment per report category, weakest first.
///
/// The question this answers is "which report are sites worst at filing?", so
/// the bars are sorted by attainment rather than by the category order. The
/// track is the category's own ceiling and the fill is the average mark
/// awarded, which makes a 15/20 and a 3/5 directly comparable without a
/// second axis. One series, so one colour — bar length already carries the
/// magnitude, and tinting by value would spend the colour channel on
/// information the length shows.
class OpsCategoryBars extends StatelessWidget {
  const OpsCategoryBars({super.key, required this.stats});

  final List<OpsCategoryStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scored = stats.where((s) => s.average != null).toList()
      ..sort((a, b) =>
          (a.attainmentPercent ?? 0).compareTo(b.attainmentPercent ?? 0));

    if (scored.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No marks allocated for this cycle yet.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Below ~520px the name needs the full row width, so it moves above
        // the bar instead of competing with it for space.
        final stacked = c.maxWidth < 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in scored)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CategoryBar(stat: s, stacked: stacked),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.stat, required this.stacked});

  final OpsCategoryStat stat;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stat.attainmentPercent ?? 0;

    final nameStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final valueStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final mutedStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    );

    final name = Text(
      _label(stat.name),
      style: nameStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final bar = _Track(fraction: pct / 100);

    // Fixed width so every track ends at the same x — a track that shifts
    // with the label's length would distort the comparison it exists for.
    final trailing = SizedBox(
      // Wide enough for the longest pair the scale can produce ("16.1/20
      // 100.0%") so nothing clips when the fallback font is wide.
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('${_trim(stat.average!)}/${stat.maxMarks}', style: valueStyle),
          const SizedBox(width: 8),
          Text('${_trim(pct)}%', style: mutedStyle),
        ],
      ),
    );

    final footnote = [
      if (stat.max != null && stat.min != null)
        'best ${stat.max} · worst ${stat.min}',
      if (stat.skippedCount > 0)
        '${stat.skippedCount} filed cycle${stat.skippedCount == 1 ? '' : 's'} skipped it',
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stacked) ...[
          name,
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: bar),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 168, child: name),
              const SizedBox(width: 12),
              Expanded(child: bar),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        if (footnote.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4, left: stacked ? 0 : 180),
            child: Text(footnote, style: mutedStyle),
          ),
      ],
    );
  }

  /// Categories are named "1) Monthly PPT"; the number is noise in a sorted
  /// list, where position no longer matches the form's numbering.
  static String _label(String name) {
    final m = RegExp(r'^\s*\d+\s*[).:-]\s*').firstMatch(name);
    return m == null ? name : name.substring(m.end);
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Track extends StatelessWidget {
  const _Track({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = fraction.clamp(0.0, 1.0);
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              // The full category ceiling — the headroom left on the table.
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                width: (c.maxWidth * f).clamp(f > 0 ? 4.0 : 0.0, c.maxWidth),
                decoration: BoxDecoration(
                  color: Vistar.pink,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
