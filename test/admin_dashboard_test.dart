import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/auth/application/auth_controller.dart';
import 'package:opsapp/features/auth/data/auth_models.dart';
import 'package:opsapp/features/dashboards/data/dashboard_models.dart';
import 'package:opsapp/features/dashboards/data/dashboards_repository.dart';
import 'package:opsapp/features/dashboards/data/ops_summary_models.dart';
import 'package:opsapp/features/dashboards/presentation/dashboard_screen.dart';
import 'package:opsapp/features/dashboards/presentation/widgets/ops_score_matrix.dart';

import 'ops_dashboard_test.dart' as fixture;

/// Holds a fixed session so the screen's role switch can be exercised without
/// a login round trip. [build] deliberately skips the real one — nothing on
/// this path touches the API or the token store.
class _FakeAuth extends AuthController {
  _FakeAuth(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

AuthState _sessionAs(UserRole role) => AuthState(
      status: AuthStatus.authenticated,
      user: AuthUser(
        id: 'u1',
        name: 'Test User',
        email: 'test@vistarlogitek.com',
        username: 'test',
        role: role,
        assignedProjectIds: const [],
        isActive: true,
      ),
    );

/// Minimal payloads for the trends view, so switching to it never reaches the
/// network in a test.
final _emptyScores = ProjectScoresPage.fromJson({
  'month': '2026-07',
  'items': <dynamic>[],
});
final _emptyTrend = MonthlyTrend.fromJson({
  'projectId': null,
  'points': <dynamic>[],
});
final _emptyCompliance = ComplianceGrid.fromJson({
  'months': <dynamic>[],
  'projects': <dynamic>[],
});

Widget _harness(UserRole role, OpsSummary summary) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuth(_sessionAs(role))),
      opsSummaryProvider.overrideWith((ref, month) async => summary),
      projectScoresProvider.overrideWith((ref, month) async => _emptyScores),
      monthlyTrendProvider.overrideWith((ref, id) async => _emptyTrend),
      complianceProvider.overrideWith((ref, r) async => _emptyCompliance),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const DashboardScreen(),
    ),
  );
}

void main() {
  final summary = OpsSummary.fromJson(fixture.buildFixture());

  testWidgets('an admin lands on the same cycle review the Ops team sees',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(UserRole.admin, summary));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Same grid, same spread footer as the Ops Excellence dashboard.
    expect(find.byType(OpsScoreMatrix), findsOneWidget);
    expect(find.text('Evaluation summary'), findsOneWidget);
    expect(find.text('Average'), findsOneWidget);
    expect(find.text('Maximum'), findsOneWidget);
    expect(find.text('Minimum'), findsOneWidget);
  });

  testWidgets('the admin keeps the across-time roll-up alongside it',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(UserRole.admin, summary));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(OpsScoreMatrix), findsNothing);
    expect(find.text('Month-over-month trend'), findsOneWidget);
    expect(find.text('Compliance heatmap'), findsOneWidget);

    // And back, without losing the grid.
    await tester.tap(find.text('Cycle review'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OpsScoreMatrix), findsOneWidget);
  });

  testWidgets('the cluster manager gets a dashboard, not a dead end',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(UserRole.clusterManager, summary));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The approver oversees a portfolio, so they get the same
    // compliance-and-trend view the project manager has.
    expect(find.text('No dashboard for this role.'), findsNothing);
    expect(find.text('Compliance — your projects'), findsOneWidget);
    expect(find.text('Average score trend'), findsOneWidget);
  });

  testWidgets('the Ops Excellence view is unchanged — no admin-only switch',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(UserRole.opsExcellence, summary));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(OpsScoreMatrix), findsOneWidget);
    expect(find.text('Trends'), findsNothing);
    expect(find.text('Cycle review'), findsNothing);
  });
}
