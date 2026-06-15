import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/audit/presentation/audit_list_screen.dart';
import '../../features/admin/categories/presentation/categories_list_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/projects/presentation/projects_list_screen.dart';
import '../../features/admin/users/presentation/users_list_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboards/presentation/dashboard_screen.dart';
import '../../features/dashboards/presentation/site_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/review/presentation/review_detail_screen.dart';
import '../../features/review/presentation/review_queue_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/submissions/presentation/cycle_picker_screen.dart';
import '../../features/submissions/presentation/submission_screen.dart';

/// Wires routes against the auth controller. While the controller is restoring
/// the session on app start, we show a splash and skip redirects so the user
/// doesn't flicker through /login.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.status == AuthStatus.unknown) return null;
      final atLogin = loc == '/login';
      final inAdmin = loc.startsWith('/admin');
      if (auth.status == AuthStatus.unauthenticated) {
        return atLogin ? null : '/login';
      }
      if (auth.isAuthenticated && atLogin) return '/';
      // Non-admins bounced out of /admin/*.
      if (inAdmin && auth.user?.role != UserRole.admin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final auth = ref.watch(authControllerProvider);
          if (auth.status == AuthStatus.unknown) return const _Splash();
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/submission/picker',
        builder: (context, state) => const CyclePickerScreen(),
      ),
      GoRoute(
        path: '/submission',
        builder: (context, state) => const SubmissionScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewQueueScreen(),
      ),
      GoRoute(
        path: '/review/:id',
        builder: (context, state) =>
            ReviewDetailScreen(submissionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dashboards',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/sites/:id',
        builder: (context, state) =>
            SiteDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            redirect: (_, _) => '/admin/projects',
          ),
          GoRoute(
            path: '/admin/projects',
            builder: (context, state) => const ProjectsListScreen(),
          ),
          GoRoute(
            path: '/admin/categories',
            builder: (context, state) => const CategoriesListScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UsersListScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AuditListScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
