import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/backend_controller.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../application/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final modeAsync = ref.watch(themeControllerProvider);
    final mode = modeAsync.maybeWhen(
      data: (m) => m,
      orElse: () => ThemeMode.system,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VistarSection(
                      title: 'Appearance',
                      child: Column(
                        children: [
                          _ThemeOption(
                            title: 'Use system setting',
                            subtitle: 'Follow your OS light/dark preference',
                            icon: Icons.brightness_auto_outlined,
                            selected: mode == ThemeMode.system,
                            onTap: () => ref
                                .read(themeControllerProvider.notifier)
                                .set(ThemeMode.system),
                          ),
                          _ThemeOption(
                            title: 'Light',
                            subtitle: 'Always use the light theme',
                            icon: Icons.light_mode_outlined,
                            selected: mode == ThemeMode.light,
                            onTap: () => ref
                                .read(themeControllerProvider.notifier)
                                .set(ThemeMode.light),
                          ),
                          _ThemeOption(
                            title: 'Dark',
                            subtitle: 'Always use the dark theme',
                            icon: Icons.dark_mode_outlined,
                            selected: mode == ThemeMode.dark,
                            onTap: () => ref
                                .read(themeControllerProvider.notifier)
                                .set(ThemeMode.dark),
                          ),
                        ],
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 16),
                      _VistarSection(
                        title: 'Account',
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  VistarAvatar(label: user.name, size: 44),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${user.username} · ${user.email}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  RibbonPill(
                                    label: roleLabel(user.role).toUpperCase(),
                                    kind: _pillForRole(user.role),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.logout),
                              title: const Text('Sign out'),
                              subtitle:
                                  const Text('Revokes the current session'),
                              onTap: () => ref
                                  .read(authControllerProvider.notifier)
                                  .logout(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _VistarSection(
                      title: 'Backend',
                      child: _BackendPicker(),
                    ),
                    const SizedBox(height: 16),
                    const _VistarSection(
                      title: 'About',
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.cloud_outlined),
                            title: Text('API base URL'),
                            subtitle: _ApiSubtitle(),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline),
                            title: Text('Vistar OPS'),
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
        ),
      ),
    );
  }

  static PillKind _pillForRole(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return PillKind.pink;
      case UserRole.manager:
        return PillKind.info;
      case UserRole.clusterManager:
        return PillKind.violet;
      case UserRole.opsExcellence:
        return PillKind.violet;
      case UserRole.siteUser:
        return PillKind.amber;
      case UserRole.unknown:
        return PillKind.neutral;
    }
  }
}

class _ApiSubtitle extends ConsumerWidget {
  const _ApiSubtitle();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(ref.watch(backendUrlProvider));
}

/// Lets the user point the app at any known deployment. Switching signs the
/// user out, because a session from one backend is not valid on another.
class _BackendPicker extends ConsumerWidget {
  const _BackendPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(backendUrlProvider);
    final isCustom = ApiConfig.optionFor(current) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which deployment this app talks to. Changing it signs you out.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 4),
        for (final b in ApiConfig.knownBackends)
          _BackendTile(
            label: b.label,
            host: b.host,
            selected: b.url == current,
            onTap: () => _switchTo(context, ref, b.url),
          ),
        if (isCustom)
          _BackendTile(
            label: 'Custom (baked into this build)',
            host: current,
            selected: true,
            onTap: null,
          ),
      ],
    );
  }

  Future<void> _switchTo(BuildContext context, WidgetRef ref, String? url) async {
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(backendUrlProvider.notifier).select(url);
    await ref.read(authControllerProvider.notifier).logout();
    messenger.showSnackBar(
      SnackBar(content: Text('Now using $url. Please sign in again.')),
    );
  }
}

class _VistarSection extends StatelessWidget {
  const _VistarSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          child,
        ],
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
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: selected ? Vistar.pink : null),
      title: Text(title,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Vistar.pink)
          : Icon(Icons.radio_button_unchecked, color: scheme.outline),
      onTap: onTap,
    );
  }
}

/// One selectable deployment. Uses a plain tile rather than RadioListTile,
/// whose groupValue/onChanged are deprecated in this Flutter version.
class _BackendTile extends StatelessWidget {
  const _BackendTile({
    required this.label,
    required this.host,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String host;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: selected ? null : onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Vistar.pink : theme.hintColor,
        size: 20,
      ),
      title: Text(label),
      subtitle: Text(
        host,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}
