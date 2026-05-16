import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../auth/application/auth_controller.dart';

class AdminSection {
  const AdminSection({required this.label, required this.icon, required this.path});
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
    final currentLoc = GoRouterState.of(context).matchedLocation;
    final selectedIndex = adminSections.indexWhere((s) => currentLoc.startsWith(s.path));
    final useRail = context.isTabletOrLarger;

    final body = useRail
        ? Row(
            children: [
              NavigationRail(
                extended: context.isDesktopOrLarger,
                selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
                onDestinationSelected: (i) => context.go(adminSections[i].path),
                labelType: context.isDesktopOrLarger
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.selected,
                destinations: [
                  for (final s in adminSections)
                    NavigationRailDestination(
                      icon: Icon(s.icon),
                      label: Text(s.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          )
        : child;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text(user.username)),
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
              onDestinationSelected: (i) => context.go(adminSections[i].path),
              destinations: [
                for (final s in adminSections)
                  NavigationDestination(icon: Icon(s.icon), label: s.label),
              ],
            ),
    );
  }
}
