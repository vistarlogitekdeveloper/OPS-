import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../auth/application/auth_controller.dart';

class AdminSection {
  const AdminSection({
    required this.label,
    required this.icon,
    required this.path,
  });
  final String label;
  final IconData icon;
  final String path;
}

const adminSections = [
  AdminSection(label: 'Projects', icon: Icons.business_outlined, path: '/admin/projects'),
  AdminSection(label: 'Categories', icon: Icons.category_outlined, path: '/admin/categories'),
  AdminSection(label: 'Users', icon: Icons.people_outline, path: '/admin/users'),
  AdminSection(label: 'Audit', icon: Icons.history_outlined, path: '/admin/audit'),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final theme = Theme.of(context);
    final currentLoc = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        adminSections.indexWhere((s) => currentLoc.startsWith(s.path));
    final useRail = context.isTabletOrLarger;

    final body = useRail
        ? Row(
            children: [
              NavigationRail(
                extended: context.isDesktopOrLarger,
                backgroundColor: Colors.transparent,
                selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
                onDestinationSelected: (i) =>
                    context.go(adminSections[i].path),
                labelType: context.isDesktopOrLarger
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.selected,
                indicatorColor: Vistar.pink.withValues(alpha: 0.18),
                selectedIconTheme: const IconThemeData(color: Vistar.pink),
                unselectedIconTheme:
                    IconThemeData(color: theme.colorScheme.onSurfaceVariant),
                selectedLabelTextStyle: const TextStyle(
                  color: Vistar.pink,
                  fontWeight: FontWeight.w700,
                ),
                destinations: [
                  for (final s in adminSections)
                    NavigationRailDestination(
                      icon: Icon(s.icon),
                      label: Text(s.label),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: theme.colorScheme.outline),
              Expanded(child: child),
            ],
          )
        : child;

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
            const Text('Admin'),
          ],
        ),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  VistarAvatar(label: user.name, size: 30),
                  const SizedBox(width: 8),
                  Text(
                    user.username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: AmbientBackground(child: SafeArea(child: body)),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              indicatorColor: Vistar.pink.withValues(alpha: 0.18),
              selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
              onDestinationSelected: (i) =>
                  context.go(adminSections[i].path),
              destinations: [
                for (final s in adminSections)
                  NavigationDestination(icon: Icon(s.icon), label: s.label),
              ],
            ),
    );
  }
}
