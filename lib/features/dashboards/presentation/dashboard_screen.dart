import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../submissions/data/submission_models.dart';
import '../data/dashboard_models.dart';
import '../../exports/presentation/export_buttons.dart';
import '../data/dashboards_repository.dart';
import 'widgets/compliance_heatmap.dart';
import 'widgets/projects_bar_chart.dart';
import 'widgets/trend_line_chart.dart';

String _currentMonth() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String _monthsAgo(int n) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month - n, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).user?.role ?? UserRole.unknown;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Image.asset(
              Vistar.smarkAsset,
              width: 32,
              height: 32,
              cacheWidth: 96,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 10),
            const Text('Dashboard'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: switch (role) {
                UserRole.siteUser => const _SiteUserDashboard(),
                UserRole.manager => const _ManagerDashboard(),
                UserRole.admin ||
                UserRole.opsExcellence =>
                  const _AdminDashboard(),
                _ => const _NoDashboard(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NoDashboard extends StatelessWidget {
  const _NoDashboard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: VistarCard(
        cornerS: true,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 36, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'No dashboard for this role.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Site user — scorecard grid ─────────────────────────────────────────────

class _SiteUserDashboard extends ConsumerWidget {
  const _SiteUserDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scorecardProvider);
    return AsyncValueView(
      value: async,
      onRetry: () => ref.invalidate(scorecardProvider),
      data: (sc) {
        if (sc.cycles.isEmpty) {
          return Center(
            child: VistarCard(
              cornerS: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined,
                      size: 36, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(
                    'No assigned projects yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(scorecardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final c in sc.cycles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScorecardCard(cycle: c),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScorecardCard extends StatelessWidget {
  const _ScorecardCard({required this.cycle});
  final ScorecardCycle cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Vistar.ribbon,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  cycle.code.length <= 4
                      ? cycle.code
                      : cycle.code.substring(0, 4),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cycle.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      cycle.code,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in cycle.months) _MonthChip(month: m),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month});
  final ScorecardMonth month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (month.status) {
      null => (
        theme.colorScheme.surfaceContainerHigh,
        theme.colorScheme.onSurfaceVariant,
      ),
      SubmissionStatus.draft => (
        Vistar.txt3.withValues(alpha: 0.18),
        Vistar.txt2,
      ),
      SubmissionStatus.submitted => (
        Vistar.info.withValues(alpha: 0.16),
        Vistar.info,
      ),
      SubmissionStatus.approved => (
        Vistar.ok.withValues(alpha: 0.16),
        Vistar.ok,
      ),
      SubmissionStatus.rejected => (
        Vistar.bad.withValues(alpha: 0.16),
        Vistar.bad,
      ),
      SubmissionStatus.unknown => (
        theme.colorScheme.surfaceContainerHigh,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final label = month.status == null
        ? '—'
        : month.totalScore == null
            ? submissionStatusLabel(month.status!)
            : '${month.totalScore}';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _short(month.month),
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 10.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _short(String m) =>
      m.length >= 7 ? '${m.substring(2, 4)}-${m.substring(5, 7)}' : m;
}

// ─── Manager — project compliance ───────────────────────────────────────────

class _ManagerDashboard extends ConsumerWidget {
  const _ManagerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ComplianceRange(from: _monthsAgo(5), to: _currentMonth());
    final async = ref.watch(complianceProvider(range));
    final trendAsync = ref.watch(monthlyTrendProvider(null));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(complianceProvider(range));
        ref.invalidate(monthlyTrendProvider(null));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ExportButtons(month: _currentMonth()),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Compliance — your projects',
            subtitle: '6-month window, % of items approved per cycle',
            child: AsyncValueView(
              value: async,
              data: (g) => ComplianceHeatmap(grid: g),
              onRetry: () => ref.invalidate(complianceProvider(range)),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Average score trend',
            subtitle: 'Across your assigned projects',
            child: AsyncValueView(
              value: trendAsync,
              data: (t) => TrendLineChart(trend: t),
              onRetry: () => ref.invalidate(monthlyTrendProvider(null)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin / Ops Excellence — full grid ─────────────────────────────────────

class _AdminDashboard extends ConsumerStatefulWidget {
  const _AdminDashboard();
  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  String _month = _currentMonth();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = ComplianceRange(from: _monthsAgo(5), to: _currentMonth());
    final scoresAsync = ref.watch(projectScoresProvider(_month));
    final trendAsync = ref.watch(monthlyTrendProvider(null));
    final complianceAsync = ref.watch(complianceProvider(range));
    // Bar chart with up to 25 rotated site labels needs full width — stack vertically.
    const cols = 1;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectScoresProvider(_month));
        ref.invalidate(monthlyTrendProvider(null));
        ref.invalidate(complianceProvider(range));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(Vistar.rSm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                        _pretty(_month),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ExportButtons(month: _month),
            ],
          ),
          const SizedBox(height: 12),
          _Grid(
            columns: cols,
            children: [
              _SectionCard(
                title: 'Project-wise score',
                subtitle: _pretty(_month),
                child: AsyncValueView(
                  value: scoresAsync,
                  data: (p) => ProjectsBarChart(page: p),
                  onRetry: () => ref.invalidate(projectScoresProvider(_month)),
                ),
              ),
              _SectionCard(
                title: 'Month-over-month trend',
                subtitle: 'Average score across all projects',
                child: AsyncValueView(
                  value: trendAsync,
                  data: (t) => TrendLineChart(trend: t),
                  onRetry: () => ref.invalidate(monthlyTrendProvider(null)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Compliance heatmap',
            subtitle: '6-month window — % of items approved per cycle',
            child: AsyncValueView(
              value: complianceAsync,
              data: (g) => ComplianceHeatmap(grid: g),
              onRetry: () => ref.invalidate(complianceProvider(range)),
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
      helpText: 'Select month for project scores',
    );
    if (picked != null) {
      setState(() {
        _month =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  String _pretty(String yyyymm) {
    try {
      final p = yyyymm.split('-');
      return DateFormat.yMMMM().format(DateTime(int.parse(p[0]), int.parse(p[1])));
    } catch (_) {
      return yyyymm;
    }
  }
}

// ─── Shared building blocks ─────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

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
          child,
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
        ],
      );
    }
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final slice = children.skip(i).take(columns).toList();
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int k = 0; k < slice.length; k++) ...[
              if (k > 0) const SizedBox(width: 12),
              Expanded(child: slice[k]),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}
