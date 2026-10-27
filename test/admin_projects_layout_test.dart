// Every admin screen sits in AdminShell. On a phone its top bar (avatar +
// username) and the list footer overflowed: production telemetry reported
// it as a rendering-library error on /admin/projects. A RenderFlex overflow
// is a FlutterError, so it is collected here instead of failing silently.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opsapp/core/models/page_result.dart';
import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/admin/presentation/admin_shell.dart';
import 'package:opsapp/features/admin/projects/application/projects_controller.dart';
import 'package:opsapp/features/admin/projects/presentation/projects_list_screen.dart';
import 'package:opsapp/features/auth/application/auth_controller.dart';
import 'package:opsapp/features/auth/data/auth_models.dart';
import 'package:opsapp/features/projects/data/project_model.dart';

class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: 'u1',
          name: 'Administrator With A Long Name',
          email: 'admin@vistarlogitek.com',
          username: 'administrator.longname',
          role: UserRole.admin,
          assignedProjectIds: [],
          isActive: true,
        ),
      );
}

class _FixedProjects extends ProjectsListController {
  @override
  Future<PageResult<Project>> build() async => PageResult(
        items: [
          for (var i = 0; i < 12; i++)
            Project(
              id: 'p$i',
              name: 'Maxion Wheels Pune Plant Chakan Phase $i Extended Site Name',
              code: 'MAXION-PUNE-CHAKAN-$i',
              location: 'Chakan MIDC, Pune, Maharashtra',
              inchargeName: 'Rajendra Kulkarni',
              inchargeEmail: null,
              inchargePhone: null,
              isActive: i.isEven,
            ),
        ],
        total: 12,
        page: 1,
        pageSize: 50,
        pageCount: 1,
      );
}

Widget _app() {
  final router = GoRouter(initialLocation: '/admin/projects', routes: [
    ShellRoute(
      builder: (_, _, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/admin/projects', builder: (_, _) => const ProjectsListScreen()),
      ],
    ),
  ]);
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_FakeAuth.new),
      projectsListControllerProvider.overrideWith(_FixedProjects.new),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

void main() {
  for (final size in const [Size(320, 640), Size(375, 812), Size(412, 915), Size(768, 1024), Size(1400, 900)]) {
    testWidgets('admin projects renders cleanly at ${size.width.toInt()}px, dialogs included', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = old);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final listErrors = [...errors];

      await tester.tap(find.text('Register site'));
      await tester.pumpAndSettle();
      final createErrors = errors.sublist(listErrors.length);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();
      final editErrors = errors.sublist(listErrors.length + createErrors.length);

      FlutterError.onError = old;
      expect({'list': listErrors, 'create': createErrors, 'edit': editErrors},
          {'list': <String>[], 'create': <String>[], 'edit': <String>[]});
    });
  }
}
