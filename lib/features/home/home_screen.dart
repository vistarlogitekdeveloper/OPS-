import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vistar.dart';
import '../../core/vistar/widgets.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    final isAdmin = user?.role == UserRole.admin;
    final isSiteOrAdmin = user != null &&
        (user.role == UserRole.siteUser || user.role == UserRole.admin);
    final isReviewer = user != null &&
        (user.role == UserRole.manager ||
            user.role == UserRole.opsExcellence ||
            user.role == UserRole.admin);

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
            const Text('Vistar OPS'),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.go('/admin/projects'),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          'Operational ',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        RibbonText(
                          'Excellence',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user == null
                          ? 'Loading session…'
                          : 'Signed in as ${user.name} · ${roleLabel(user.role)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _KpiStrip(),
                    const SizedBox(height: 32),
                    const SectionTitle('Quick actions'),
                    LayoutBuilder(builder: (context, c) {
                      const gap = 12.0;
                      final tiles = <Widget>[
                        if (isSiteOrAdmin)
                          _ActionCard(
                            icon: Icons.upload_file_outlined,
                            title: 'Monthly submission',
                            subtitle: 'Upload your monthly report files',
                            onTap: () => context.go('/submission/picker'),
                          ),
                        if (isReviewer)
                          _ActionCard(
                            icon: Icons.rule_folder_outlined,
                            title: 'Review queue',
                            subtitle: user.role == UserRole.opsExcellence
                                ? 'Open approved submissions to allocate marks'
                                : 'Approve or reject submitted reports',
                            onTap: () => context.go('/review'),
                          ),
                        if (user != null)
                          _ActionCard(
                            icon: Icons.insert_chart_outlined,
                            title: 'Dashboard',
                            subtitle: 'Scores, compliance, trends',
                            onTap: () => context.go('/dashboards'),
                          ),
                      ];
                      // Pick a column count that exactly divides the tile
                      // count when possible — keeps rows full (no orphans).
                      final maxFit = c.maxWidth >= 900
                          ? 3
                          : c.maxWidth >= 600
                              ? 2
                              : 1;
                      final cols = tiles.isEmpty
                          ? 1
                          : tiles.length <= maxFit
                              ? tiles.length
                              : maxFit;
                      // Build rows of `cols` Expanded cards inside
                      // IntrinsicHeight so every card in a row matches the
                      // tallest one (subtitles can wrap without breaking
                      // the row's visual alignment).
                      final rows = <Widget>[];
                      for (int i = 0; i < tiles.length; i += cols) {
                        final slice = tiles.skip(i).take(cols).toList();
                        rows.add(IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int k = 0; k < slice.length; k++) ...[
                                if (k > 0) const SizedBox(width: gap),
                                Expanded(child: slice[k]),
                              ],
                              // Pad short final row so cards keep their column width.
                              for (int k = slice.length; k < cols; k++) ...[
                                const SizedBox(width: gap),
                                const Expanded(child: SizedBox.shrink()),
                              ],
                            ],
                          ),
                        ));
                      }
                      return Column(
                        children: [
                          for (int r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: gap),
                            rows[r],
                          ],
                        ],
                      );
                    }),
                    ?(user != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle('Account'),
                                _AccountCard(user: user),
                              ],
                            ),
                          )
                        : null),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final stack = c.maxWidth < 640;
      const tiles = [
        _Kpi(icon: Icons.business_outlined, label: 'Project sites', value: '25'),
        _Kpi(icon: Icons.category_outlined, label: 'Categories', value: '10'),
        _Kpi(
            icon: Icons.workspace_premium_outlined,
            label: 'Mark rubric',
            value: '100'),
      ];
      if (stack) {
        return Column(
          children: [
            for (final t in tiles) ...[
              t,
              if (t != tiles.last) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      glow: true,
      cornerS: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Vistar.pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: Vistar.pink),
          ),
          const SizedBox(height: 14),
          RibbonText(
            value,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              letterSpacing: -0.4,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      onTap: onTap,
      glow: true,
      cornerS: true,
      padding: const EdgeInsets.all(18),
      child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Vistar.pink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Vistar.pink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});
  final dynamic user; // AuthUser — kept dynamic to avoid leaking the type here.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          VistarAvatar(label: user.name as String, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name as String,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.username} · ${user.email}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          RibbonPill(
            label: roleLabel(user.role as UserRole).toUpperCase(),
            kind: _pillForRole(user.role as UserRole),
          ),
        ],
      ),
    );
  }

  static PillKind _pillForRole(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return PillKind.pink;
      case UserRole.manager:
        return PillKind.info;
      case UserRole.opsExcellence:
        return PillKind.violet;
      case UserRole.siteUser:
        return PillKind.amber;
      case UserRole.unknown:
        return PillKind.neutral;
    }
  }
}
