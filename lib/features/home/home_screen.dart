import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = context.screenSize;
    final user = ref.watch(authControllerProvider).user;

    final showSubmissions =
        user != null && (user.role == UserRole.siteUser || user.role == UserRole.admin);
    final showReview = user != null &&
        (user.role == UserRole.manager ||
            user.role == UserRole.opsExcellence ||
            user.role == UserRole.admin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpsApp'),
        actions: [
          if (user?.role == UserRole.admin)
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
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operational Excellence Report & Compliance Management',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  user == null
                      ? 'Loading session…'
                      : 'Signed in as ${user.name} (${roleLabel(user.role)})',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (showSubmissions)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.upload_file_outlined),
                      title: const Text('Monthly submission'),
                      subtitle: const Text('Upload your monthly report files'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/submission/picker'),
                    ),
                  ),
                if (showSubmissions) const SizedBox(height: 12),
                if (showReview)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.rule_folder_outlined),
                      title: const Text('Review queue'),
                      subtitle: Text(user.role == UserRole.opsExcellence
                          ? 'Open approved submissions to allocate marks'
                          : 'Approve or reject submitted reports'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/review'),
                    ),
                  ),
                if (showReview) const SizedBox(height: 12),
                if (user != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_chart_outlined),
                      title: const Text('Dashboard'),
                      subtitle: const Text('Scores, compliance, trends'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/dashboards'),
                    ),
                  ),
                if (user != null) const SizedBox(height: 12),
                if (user != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      subtitle: const Text('Theme, account, about'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/settings'),
                    ),
                  ),
                if (user != null) const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current breakpoint', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(size.name, style: theme.textTheme.bodyLarge),
                        if (user != null) ...[
                          const SizedBox(height: 16),
                          Text('Account', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('${user.username} · ${user.email}',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
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
