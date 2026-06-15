import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../submissions/data/submission_models.dart';
import '../data/dashboard_models.dart';
import '../data/dashboards_repository.dart';

/// Per-site dashboard: in-charge contact, latest score + status, monthly score
/// trend, compliance over time, and the category-by-category breakdown.
class SiteDetailScreen extends ConsumerWidget {
  const SiteDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(siteDashboardProvider(projectId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Site dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: AsyncValueView(
                value: async,
                onRetry: () => ref.invalidate(siteDashboardProvider(projectId)),
                data: (d) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(siteDashboardProvider(projectId)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _Header(d: d),
                      const SizedBox(height: 16),
                      _LatestAndContact(d: d),
                      const SizedBox(height: 20),
                      const SectionTitle('Monthly score trend'),
                      const SizedBox(height: 8),
                      _Trend(points: d.trend),
                      const SizedBox(height: 20),
                      const SectionTitle('Compliance over time'),
                      const SizedBox(height: 8),
                      _Compliance(points: d.compliance),
                      const SizedBox(height: 20),
                      SectionTitle(
                        'Category breakdown'
                        '${d.latestMonth != null ? ' · ${d.latestMonth}' : ''}',
                      ),
                      const SizedBox(height: 8),
                      _Breakdown(items: d.breakdown),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PillKind _statusPill(SubmissionStatus? s) => switch (s) {
      SubmissionStatus.approved => PillKind.ok,
      SubmissionStatus.submitted => PillKind.info,
      SubmissionStatus.rejected => PillKind.bad,
      SubmissionStatus.draft => PillKind.amber,
      _ => PillKind.neutral,
    };

class _Header extends StatelessWidget {
  const _Header({required this.d});
  final SiteDashboard d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = d.project;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [p.code, if (p.location != null) p.location].join(' · '),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        RibbonPill(
          label: (p.isActive ? 'ACTIVE' : 'INACTIVE'),
          kind: p.isActive ? PillKind.ok : PillKind.neutral,
        ),
      ],
    );
  }
}

class _LatestAndContact extends StatelessWidget {
  const _LatestAndContact({required this.d});
  final SiteDashboard d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = d.project;
    final hasContact = (p.inchargeName != null && p.inchargeName!.isNotEmpty) ||
        (p.inchargeEmail != null && p.inchargeEmail!.isNotEmpty) ||
        (p.inchargePhone != null && p.inchargePhone!.isNotEmpty);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Latest score card.
        Expanded(
          child: VistarCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LATEST SCORE',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      d.latestScore?.toString() ?? '—',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Vistar.pink,
                      ),
                    ),
                    Text(' / 100',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RibbonPill(
                      label: (d.latestStatus == null
                              ? 'NO CYCLE'
                              : submissionStatusLabel(d.latestStatus!))
                          .toUpperCase(),
                      kind: _statusPill(d.latestStatus),
                    ),
                    if (d.latestMonth != null) ...[
                      const SizedBox(width: 8),
                      Text(d.latestMonth!,
                          style:
                              TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // In-charge contact card.
        Expanded(
          child: VistarCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SITE IN-CHARGE',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                if (!hasContact)
                  Text('Not set',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant))
                else ...[
                  if (p.inchargeName != null && p.inchargeName!.isNotEmpty)
                    _ContactLine(icon: Icons.person_outline, text: p.inchargeName!),
                  if (p.inchargeEmail != null && p.inchargeEmail!.isNotEmpty)
                    _ContactLine(icon: Icons.mail_outline, text: p.inchargeEmail!),
                  if (p.inchargePhone != null && p.inchargePhone!.isNotEmpty)
                    _ContactLine(icon: Icons.phone_outlined, text: p.inchargePhone!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.points});
  final List<SiteTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) return const _EmptyNote('No score history yet.');
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final p in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(p.month,
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (p.totalScore.clamp(0, 100)) / 100,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Vistar.pink),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${p.totalScore}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Compliance extends StatelessWidget {
  const _Compliance({required this.points});
  final List<SiteCompliancePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) return const _EmptyNote('No compliance data yet.');
    Color colorFor(int? pct) {
      if (pct == null) return theme.colorScheme.surfaceContainerHigh;
      if (pct >= 80) return Vistar.ok;
      if (pct >= 50) return Vistar.amber;
      return Vistar.bad;
    }

    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in points)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorFor(p.percent).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorFor(p.percent), width: 1.5),
                  ),
                  child: Text(
                    p.percent == null ? '—' : '${p.percent}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(p.month.substring(5),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.items});
  final List<SiteCategoryMark> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return const _EmptyNote('No submitted cycle to break down yet.');
    }
    return VistarCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final c in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${c.awardedMarks ?? '—'} / ${c.maxMarks}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: c.awardedMarks == null
                              ? theme.colorScheme.onSurfaceVariant
                              : Vistar.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.maxMarks == 0
                          ? 0
                          : (c.awardedMarks ?? 0) / c.maxMarks,
                      minHeight: 7,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Vistar.violet),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return VistarCard(
      padding: const EdgeInsets.all(20),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
