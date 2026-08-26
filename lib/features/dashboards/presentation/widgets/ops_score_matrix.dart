import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/vistar.dart';
import '../../../submissions/data/submission_models.dart';
import '../../data/ops_summary_models.dart';

/// What the matrix cells encode.
enum MatrixMode {
  /// Marks awarded per category — the evaluation summary.
  marks,

  /// Whether the file arrived at all — the submission review grid.
  uploads,
}

/// Sites down, report categories across: the whole cycle on one grid.
///
/// Columns are headed by the category's position and ceiling rather than its
/// name — ten names at cell width would clip, so the key below the grid maps
/// number to name. Every cell prints its own value, so the heat tint is a
/// second read of the number and never the only one. In [MatrixMode.marks] the
/// grid closes with the Average / Maximum / Minimum rows the cycle is judged
/// on.
class OpsScoreMatrix extends StatelessWidget {
  const OpsScoreMatrix({
    super.key,
    required this.summary,
    required this.rows,
    required this.mode,
    this.onRowTap,
  });

  final OpsSummary summary;

  /// The rows to render, already ordered by the caller's sort choice.
  final List<OpsSummaryRow> rows;
  final MatrixMode mode;
  final void Function(OpsSummaryRow row)? onRowTap;

  static const double _siteW = 216;
  static const double _cellW = 54;
  static const double _totalW = 66;
  static const double _cellH = 34;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = summary.categories;
    if (cats.isEmpty || rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nothing to show for this cycle.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final statByCategory = {
      for (final s in summary.stats.categories) s.categoryId: s,
    };
    final width = _siteW + cats.length * _cellW + _totalW;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(categories: cats, mode: mode),
                const SizedBox(height: 4),
                for (final row in rows)
                  _DataRow(
                    row: row,
                    categories: cats,
                    mode: mode,
                    maxTotal: summary.maxTotal,
                    onTap: onRowTap == null ? null : () => onRowTap!(row),
                  ),
                if (mode == MatrixMode.marks) ...[
                  const SizedBox(height: 6),
                  _Divider(width: width),
                  const SizedBox(height: 6),
                  _SpreadRow(
                    label: 'Average',
                    categories: cats,
                    valueOf: (c) => statByCategory[c.id]?.average,
                    total: summary.stats.total.average,
                  ),
                  _SpreadRow(
                    label: 'Maximum',
                    categories: cats,
                    valueOf: (c) => statByCategory[c.id]?.max?.toDouble(),
                    total: summary.stats.total.max?.toDouble(),
                  ),
                  _SpreadRow(
                    label: 'Minimum',
                    categories: cats,
                    valueOf: (c) => statByCategory[c.id]?.min?.toDouble(),
                    total: summary.stats.total.min?.toDouble(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Legend(mode: mode),
        const SizedBox(height: 12),
        _ColumnKey(categories: cats),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.categories, required this.mode});

  final List<OpsSummaryCategory> categories;
  final MatrixMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TextStyle(
      color: theme.hintColor,
      fontSize: 10.5,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: OpsScoreMatrix._siteW,
          child: Text('SITE', style: style),
        ),
        for (int i = 0; i < categories.length; i++)
          SizedBox(
            width: OpsScoreMatrix._cellW,
            child: Tooltip(
              message: categories[i].name,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${i + 1}', style: style),
                  if (mode == MatrixMode.marks)
                    Text(
                      '/${categories[i].maxMarks}',
                      style: style.copyWith(fontSize: 9.5, letterSpacing: 0),
                    ),
                ],
              ),
            ),
          ),
        SizedBox(
          width: OpsScoreMatrix._totalW,
          child: Center(
            child: Text(
              mode == MatrixMode.marks ? 'TOTAL' : 'FILED',
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.categories,
    required this.mode,
    required this.maxTotal,
    this.onTap,
  });

  final OpsSummaryRow row;
  final List<OpsSummaryCategory> categories;
  final MatrixMode mode;
  final int maxTotal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cellByCategory = {for (final c in row.cells) c.categoryId: c};

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: OpsScoreMatrix._siteW,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                // Several sites share a name up to their branch suffix
                // ("… (PUNE)" vs "… (BANGALORE)"), which is exactly the part
                // truncation eats — so the full name stays one hover away.
                child: Tooltip(
                  message: '${row.name}\n${row.code}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: row.submitted
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        row.submitted
                            ? (row.evaluator ?? row.submittedBy ?? row.code)
                            : 'not filed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: row.submitted
                              ? theme.hintColor
                              : Vistar.bad.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final c in categories)
              SizedBox(
                width: OpsScoreMatrix._cellW,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _Cell(
                    category: c,
                    cell: cellByCategory[c.id],
                    submitted: row.submitted,
                    mode: mode,
                  ),
                ),
              ),
            SizedBox(
              width: OpsScoreMatrix._totalW,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _TotalCell(row: row, mode: mode, maxTotal: maxTotal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.category,
    required this.cell,
    required this.submitted,
    required this.mode,
  });

  final OpsSummaryCategory category;
  final OpsSummaryCell? cell;
  final bool submitted;
  final MatrixMode mode;

  @override
  Widget build(BuildContext context) {
    final c = cell;
    final (bg, fg, label) = switch (mode) {
      MatrixMode.uploads => _uploadPaint(c),
      MatrixMode.marks => _markPaint(c),
    };

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${category.name}\n',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: _tooltipBody(c)),
        ],
      ),
      child: Container(
        height: OpsScoreMatrix._cellH - 4,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  String _tooltipBody(OpsSummaryCell? c) {
    if (!submitted) return 'No cycle filed for this site.';
    if (c == null || !c.uploaded) return 'Nothing uploaded (max ${category.maxMarks}).';
    final parts = <String>[
      c.awardedMarks == null
          ? 'Awaiting marks (max ${category.maxMarks})'
          : 'Marks: ${c.awardedMarks}/${category.maxMarks}',
      if (c.status != null) 'Status: ${itemStatusLabel(c.status!)}',
      if (c.uploadedAt != null)
        'Uploaded: ${DateFormat('d MMM y').format(c.uploadedAt!.toLocal())}',
      if (c.remark != null && c.remark!.trim().isNotEmpty) '\n“${c.remark!.trim()}”',
    ];
    return parts.join('\n');
  }

  /// Marks read as heat against the category ceiling. Every cell also prints
  /// its number, so the tint is a second encoding rather than the only one.
  static (Color, Color, String) _markPaint(OpsSummaryCell? c) {
    if (c == null || !c.uploaded) {
      return (const Color(0x14FFFFFF), Vistar.txt3, '—');
    }
    if (c.awardedMarks == null) {
      return (Vistar.info.withValues(alpha: 0.14), Vistar.info, '·');
    }
    final pct = ((c.attainment ?? 0) * 100).round();
    final label = '${c.awardedMarks}';
    if (pct == 0) return (Vistar.bad.withValues(alpha: 0.20), Vistar.bad, label);
    if (pct < 50) {
      return (Vistar.orange.withValues(alpha: 0.22), Vistar.orange, label);
    }
    if (pct < 100) {
      return (Vistar.amber.withValues(alpha: 0.22), Vistar.amber, label);
    }
    return (Vistar.ok.withValues(alpha: 0.22), Vistar.ok, label);
  }

  static (Color, Color, String) _uploadPaint(OpsSummaryCell? c) {
    if (c != null && c.uploaded) {
      return (Vistar.ok.withValues(alpha: 0.20), Vistar.ok, 'Y');
    }
    return (Vistar.bad.withValues(alpha: 0.18), Vistar.bad, 'N');
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.row,
    required this.mode,
    required this.maxTotal,
  });

  final OpsSummaryRow row;
  final MatrixMode mode;
  final int maxTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String label;
    final String tip;
    if (mode == MatrixMode.uploads) {
      label = '${row.uploadedCount}/${row.cells.length}';
      tip = row.submittedAt == null
          ? 'No submission date recorded.'
          : 'Filed ${DateFormat('d MMM y, HH:mm').format(row.submittedAt!.toLocal())}';
    } else if (row.totalScore == null) {
      label = '—';
      tip = 'No cycle filed.';
    } else {
      label = '${row.totalScore}';
      tip = 'Total ${row.totalScore} of $maxTotal'
          '${row.scoredCount < row.cells.length ? ' · ${row.cells.length - row.scoredCount} item(s) still unmarked' : ''}';
    }

    return Tooltip(
      message: tip,
      child: Container(
        height: OpsScoreMatrix._cellH - 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: row.submitted ? 0.9 : 0.45),
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: row.submitted
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// The Average / Maximum / Minimum footer the cycle is judged on.
class _SpreadRow extends StatelessWidget {
  const _SpreadRow({
    required this.label,
    required this.categories,
    required this.valueOf,
    required this.total,
  });

  final String label;
  final List<OpsSummaryCategory> categories;
  final double? Function(OpsSummaryCategory) valueOf;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cellStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: OpsScoreMatrix._siteW,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          for (final c in categories)
            SizedBox(
              width: OpsScoreMatrix._cellW,
              child: Center(child: Text(_fmt(valueOf(c)), style: cellStyle)),
            ),
          SizedBox(
            width: OpsScoreMatrix._totalW,
            child: Center(
              child: Text(
                _fmt(total),
                style: cellStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.mode});
  final MatrixMode mode;

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
      children: mode == MatrixMode.uploads
          ? [
              swatch(Vistar.ok, 'Y — file received'),
              swatch(Vistar.bad, 'N — nothing uploaded'),
            ]
          : [
              swatch(Vistar.txt3, 'Not uploaded'),
              swatch(Vistar.info, 'Awaiting marks'),
              swatch(Vistar.bad, 'Zero'),
              swatch(Vistar.orange, 'Below half'),
              swatch(Vistar.amber, 'Half to full'),
              swatch(Vistar.ok, 'Full marks'),
            ],
    );
  }
}

/// Maps the numbered columns back to the category names.
class _ColumnKey extends StatelessWidget {
  const _ColumnKey({required this.categories});
  final List<OpsSummaryCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 18,
      runSpacing: 4,
      children: [
        for (int i = 0; i < categories.length; i++)
          Text(
            '${i + 1}. ${categories[i].shortName}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
