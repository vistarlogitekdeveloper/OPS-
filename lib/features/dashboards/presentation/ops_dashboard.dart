import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../exports/presentation/export_buttons.dart';
import '../../submissions/data/submission_models.dart';
import '../data/dashboards_repository.dart';
import '../data/ops_summary_models.dart';
import 'widgets/ops_category_bars.dart';
import 'widgets/ops_score_matrix.dart';

/// The Ops Excellence cycle review.
///
/// This is the screen the Ops team lands on, and it replaces the pair of
/// spreadsheets the cycle used to be assembled in: the evaluation summary
/// (marks and remarks per site per report, closed by the Average / Maximum /
/// Minimum footer) and the submission review grid (did the file arrive, and
/// when). Both are the same matrix, so they live behind one switch rather
/// than in two places that can disagree.
class OpsExcellenceDashboard extends ConsumerStatefulWidget {
  const OpsExcellenceDashboard({super.key});

  @override
  ConsumerState<OpsExcellenceDashboard> createState() =>
      _OpsExcellenceDashboardState();
}

/// How the matrix orders its sites.
enum _RowSort { site, score }

class _OpsExcellenceDashboardState
    extends ConsumerState<OpsExcellenceDashboard> {
  String _month = _currentMonth();
  MatrixMode _mode = MatrixMode.marks;
  _RowSort _sort = _RowSort.site;

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(opsSummaryProvider(_month));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(opsSummaryProvider(_month)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // One filter row above everything it scopes — every card below
          // reads the same cycle.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MonthButton(month: _month, onPick: _pickMonth),
              ExportButtons(month: _month),
            ],
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: async,
            onRetry: () => ref.invalidate(opsSummaryProvider(_month)),
            data: (s) => _Body(
              summary: s,
              mode: _mode,
              sort: _sort,
              onModeChanged: (m) => setState(() => _mode = m),
              onSortChanged: (v) => setState(() => _sort = v),
              onRowTap: (row) => _showRow(context, s, row),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final parts = _month.split('-');
    final initial = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select the reporting cycle',
    );
    if (picked != null) {
      setState(() {
        _month = '${picked.year.toString().padLeft(4, '0')}'
            '-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showRow(BuildContext context, OpsSummary summary, OpsSummaryRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RowSheet(summary: summary, row: row),
    );
  }
}

String prettyMonth(String yyyymm) {
  try {
    final p = yyyymm.split('-');
    return DateFormat.yMMMM().format(DateTime(int.parse(p[0]), int.parse(p[1])));
  } catch (_) {
    return yyyymm;
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.summary,
    required this.mode,
    required this.sort,
    required this.onModeChanged,
    required this.onSortChanged,
    required this.onRowTap,
  });

  final OpsSummary summary;
  final MatrixMode mode;
  final _RowSort sort;
  final ValueChanged<MatrixMode> onModeChanged;
  final ValueChanged<_RowSort> onSortChanged;
  final void Function(OpsSummaryRow) onRowTap;

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;
    final pending = summary.notSubmitted;
    final rows = sort == _RowSort.score ? summary.ranked : summary.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiStrip(summary: summary),
        const SizedBox(height: 16),
        _Card(
          title: 'Weakest reporting areas',
          subtitle: 'Average mark against each report’s ceiling, worst first',
          child: OpsCategoryBars(stats: stats.categories),
        ),
        const SizedBox(height: 16),
        _Card(
          title: mode == MatrixMode.marks
              ? 'Evaluation summary'
              : 'Submission review',
          subtitle: mode == MatrixMode.marks
              ? '${prettyMonth(summary.month)} · marks awarded per report — tap a site for its remarks'
              : '${prettyMonth(summary.month)} · whether each report was filed',
          controls: _MatrixControls(
            mode: mode,
            sort: sort,
            onModeChanged: onModeChanged,
            onSortChanged: onSortChanged,
          ),
          child: OpsScoreMatrix(
            summary: summary,
            rows: rows,
            mode: mode,
            onRowTap: onRowTap,
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Card(
            title: 'Nothing filed yet',
            subtitle:
                '${pending.length} site${pending.length == 1 ? '' : 's'} with no cycle for ${prettyMonth(summary.month)}',
            child: _ChaseList(rows: pending),
          ),
        ],
      ],
    );
  }
}

// ─── KPI tiles ──────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.summary});
  final OpsSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary.stats;
    final tiles = <Widget>[
      _KpiTile(
        label: 'Filed',
        value: '${s.submittedCount}/${s.projectCount}',
        note: '${(s.submissionRate * 100).round()}% of active sites',
        tone: s.missingCount == 0 ? Vistar.ok : Vistar.amber,
      ),
      _KpiTile(
        label: 'Awaiting marks',
        value: '${s.awaitingMarksCount}',
        note: s.awaitingMarksCount == 0
            ? 'Marking complete'
            : 'Cycles filed but not scored',
        tone: s.awaitingMarksCount == 0 ? Vistar.ok : Vistar.info,
      ),
      _KpiTile(
        label: 'Average score',
        value: s.total.average == null
            ? '—'
            : _trim(s.total.average!),
        note: 'out of ${summary.maxTotal}',
        tone: Vistar.pink,
      ),
      _KpiTile(
        label: 'Best · worst',
        value: s.total.max == null || s.total.min == null
            ? '—'
            : '${s.total.max} · ${s.total.min}',
        note: 'across ${s.scoredCount} scored cycle${s.scoredCount == 1 ? '' : 's'}',
        tone: Vistar.violet,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900
            ? 4
            : c.maxWidth >= 560
                ? 2
                : 1;
        const gap = 12.0;
        final rows = <Widget>[];
        for (int i = 0; i < tiles.length; i += cols) {
          final slice = tiles.skip(i).take(cols).toList();
          rows.add(Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int k = 0; k < slice.length; k++) ...[
                    if (k > 0) const SizedBox(width: gap),
                    Expanded(child: slice[k]),
                  ],
                  // Keep the last row's tiles the same width as a full row's.
                  for (int k = slice.length; k < cols; k++) ...[
                    const SizedBox(width: gap),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.note,
    required this.tone,
  });

  final String label;
  final String value;
  final String note;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chase list ─────────────────────────────────────────────────────────────

class _ChaseList extends StatelessWidget {
  const _ChaseList({required this.rows});
  final List<OpsSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in rows)
          InkWell(
            onTap: () => context.go('/sites/${r.projectId}'),
            borderRadius: BorderRadius.circular(Vistar.rSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Vistar.bad.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Vistar.rSm),
                border: Border.all(color: Vistar.bad.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.report_gmailerrorred_outlined,
                      size: 15, color: Vistar.bad),
                  const SizedBox(width: 7),
                  // Site names run long enough to exceed a phone's width, so
                  // the label gives way rather than overflowing the chip.
                  Flexible(
                    child: Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Per-site detail sheet ──────────────────────────────────────────────────

/// One site's line, unrolled: every report with its mark and the remark that
/// justifies it. The matrix can only show the number, so this is where the
/// reasoning lives — and it doubles as the readable, non-colour version of
/// that row.
class _RowSheet extends StatelessWidget {
  const _RowSheet({required this.summary, required this.row});

  final OpsSummary summary;
  final OpsSummaryRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {for (final c in row.cells) c.categoryId: c};

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            row.name,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text(
            [
              row.code,
              if (row.location != null && row.location!.isNotEmpty) row.location!,
              prettyMonth(summary.month),
            ].join(' · '),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (row.status != null)
                RibbonPill(
                  label: submissionStatusLabel(row.status!),
                  kind: switch (row.status!) {
                    SubmissionStatus.approved => PillKind.ok,
                    SubmissionStatus.rejected => PillKind.bad,
                    SubmissionStatus.managerApproved => PillKind.info,
                    SubmissionStatus.submitted => PillKind.info,
                    _ => PillKind.neutral,
                  },
                )
              else
                const RibbonPill(label: 'Not filed', kind: PillKind.bad),
              if (row.totalScore != null)
                RibbonPill(
                  label: 'Total ${row.totalScore}/${summary.maxTotal}',
                  kind: PillKind.violet,
                ),
              if (row.evaluator != null)
                RibbonPill(label: 'Evaluator: ${row.evaluator}', kind: PillKind.pink),
              if (row.submittedAt != null)
                RibbonPill(
                  label:
                      'Filed ${DateFormat('d MMM y').format(row.submittedAt!.toLocal())}',
                  kind: PillKind.neutral,
                ),
            ],
          ),
          if (row.comments != null && row.comments!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              row.comments!.trim(),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Report-wise marks'),
          for (final cat in summary.categories)
            _CategoryLine(category: cat, cell: byId[cat.id]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/sites/${row.projectId}');
              },
              icon: const Icon(Icons.north_east, size: 16),
              label: const Text('Open site'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.category, required this.cell});

  final OpsSummaryCategory category;
  final OpsSummaryCell? cell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cell;
    final marks = c?.awardedMarks;
    final remark = c?.remark?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                marks == null
                    ? (c?.uploaded == true ? 'unmarked' : 'not filed')
                    : '$marks/${category.maxMarks}',
                style: TextStyle(
                  color: marks == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (remark != null && remark.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                remark,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Chrome ─────────────────────────────────────────────────────────────────

/// What the grid shows, and in what order. These change the view of one card
/// rather than the data every card reads, so they sit with the grid instead of
/// in the cycle filter row at the top.
class _MatrixControls extends StatelessWidget {
  const _MatrixControls({
    required this.mode,
    required this.sort,
    required this.onModeChanged,
    required this.onSortChanged,
  });

  final MatrixMode mode;
  final _RowSort sort;
  final ValueChanged<MatrixMode> onModeChanged;
  final ValueChanged<_RowSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        SegmentedButton<MatrixMode>(
          showSelectedIcon: false,
          style: style,
          segments: const [
            ButtonSegment(value: MatrixMode.marks, label: Text('Marks')),
            ButtonSegment(value: MatrixMode.uploads, label: Text('Filed')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        SegmentedButton<_RowSort>(
          showSelectedIcon: false,
          style: style,
          segments: const [
            ButtonSegment(value: _RowSort.site, label: Text('A–Z')),
            ButtonSegment(value: _RowSort.score, label: Text('By score')),
          ],
          selected: {sort},
          onSelectionChanged: (s) => onSortChanged(s.first),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.month, required this.onPick});

  final String month;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(Vistar.rSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Vistar.rSm),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Vistar.pink),
            const SizedBox(width: 8),
            Text(
              prettyMonth(month),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
    this.controls,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// View controls for this card, laid out under the heading so they can wrap
  /// on a phone instead of squeezing the title.
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 12),
            child: Text(
              subtitle,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          ),
          if (controls != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: controls,
            ),
          child,
        ],
      ),
    );
  }
}
