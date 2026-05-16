import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../application/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final modeAsync = ref.watch(themeControllerProvider);
    final mode = modeAsync.maybeWhen(data: (m) => m, orElse: () => ThemeMode.system);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Appearance',
                  child: Column(
                    children: [
                      _ThemeOption(
                        title: 'Use system setting',
                        subtitle: 'Follow your OS light/dark preference',
                        icon: Icons.brightness_auto_outlined,
                        selected: mode == ThemeMode.system,
                        onTap: () =>
                            ref.read(themeControllerProvider.notifier).set(ThemeMode.system),
                      ),
                      _ThemeOption(
                        title: 'Light',
                        subtitle: 'Always use the light theme',
                        icon: Icons.light_mode_outlined,
                        selected: mode == ThemeMode.light,
                        onTap: () =>
                            ref.read(themeControllerProvider.notifier).set(ThemeMode.light),
                      ),
                      _ThemeOption(
                        title: 'Dark',
                        subtitle: 'Always use the dark theme',
                        icon: Icons.dark_mode_outlined,
                        selected: mode == ThemeMode.dark,
                        onTap: () =>
                            ref.read(themeControllerProvider.notifier).set(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (user != null)
                  _Section(
                    title: 'Account',
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(user.name),
                          subtitle: Text('${user.username} · ${user.email}'),
                          trailing: Chip(
                            label: Text(roleLabel(user.role)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            labelStyle:
                                TextStyle(color: theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign out'),
                          subtitle: const Text('Revokes the current session'),
                          onTap: () =>
                              ref.read(authControllerProvider.notifier).logout(),
                        ),
                      ],
                    ),
                  ),
                if (user != null) const SizedBox(height: 12),
                _Section(
                  title: 'About',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud_outlined),
                        title: const Text('API base URL'),
                        subtitle: Text(ApiConfig.baseUrl),
                      ),
                      const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('OpsApp'),
                        subtitle: Text(
                          'Operational Excellence Report & Compliance Management',
                        ),
                      ),
                    ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? scheme.primary : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected ? Icon(Icons.check_circle, color: scheme.primary) : const Icon(Icons.radio_button_unchecked),
      onTap: onTap,
    );
  }
}
