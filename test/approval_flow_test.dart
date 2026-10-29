import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/auth/application/auth_controller.dart';
import 'package:opsapp/features/auth/data/auth_models.dart';
import 'package:opsapp/features/home/home_screen.dart';
import 'package:opsapp/features/review/application/review_controllers.dart';
import 'package:opsapp/features/submissions/data/submission_models.dart';

/// Holds a fixed session so role gating can be exercised without a login round
/// trip. [build] deliberately skips the real one — nothing here touches the API
/// or the token store.
class _FakeAuth extends AuthController {
  _FakeAuth(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

/// A session for an employee holding one role, or several at once.
AuthState _sessionWith(List<UserRole> roles) => AuthState(
      status: AuthStatus.authenticated,
      user: AuthUser(
        id: 'u1',
        name: 'Test User',
        email: 'test@vistarlogitek.com',
        username: 'test',
        roles: roles,
        assignedProjectIds: const ['p1'],
        isActive: true,
      ),
    );

Widget _homeWith(List<UserRole> roles) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuth(_sessionWith(roles))),
        // The badge would otherwise hit the network.
        pendingReviewCountProvider
            .overrideWith((ref) async => PendingReviewCount.empty),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
    );

Future<void> _pumpHome(WidgetTester tester, UserRole role) =>
    _pumpHomeWith(tester, [role]);

Future<void> _pumpHomeWith(WidgetTester tester, List<UserRole> roles) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_homeWith(roles));
  await tester.pumpAndSettle();
}

Submission _submission({required String submittedBy}) => Submission.fromJson({
      'id': 's1',
      'projectId': 'p1',
      'month': '2026-10',
      'status': 'SUBMITTED',
      'submittedBy': submittedBy,
      'items': const [],
    });

void main() {
  group('status vocabulary', () {
    test('a filed cycle waits on the cluster manager', () {
      expect(
        submissionStatusLabel(SubmissionStatus.submitted),
        'Awaiting Cluster Manager',
      );
    });

    test('the retired middle state reads as the same wait', () {
      // Nothing writes MANAGER_APPROVED any more, but the backfill that clears
      // it is applied by hand — a row still carrying it is waiting on exactly
      // the same person, so it must not read as a separate stage.
      expect(
        submissionStatusLabel(SubmissionStatus.managerApproved),
        submissionStatusLabel(SubmissionStatus.submitted),
      );
    });

    test('both pending states count as awaiting approval', () {
      expect(isAwaitingApproval(SubmissionStatus.submitted), isTrue);
      expect(isAwaitingApproval(SubmissionStatus.managerApproved), isTrue);
      // Settled states are nobody's queue.
      expect(isAwaitingApproval(SubmissionStatus.draft), isFalse);
      expect(isAwaitingApproval(SubmissionStatus.approved), isFalse);
      expect(isAwaitingApproval(SubmissionStatus.rejected), isFalse);
    });

    test('the approver is labelled the way the business names it', () {
      expect(roleLabel(UserRole.clusterManager), 'Cluster Manager');
      expect(roleLabel(UserRole.manager), 'Project Manager');
    });

    test('an approval row names the stage that took it', () {
      SubmissionApproval row(String stage, String decision) =>
          SubmissionApproval.fromJson({
            'stage': stage,
            'decision': decision,
            'createdAt': '2026-09-01T10:00:00.000Z',
          });
      expect(row('REGIONAL', 'APPROVE').stageLabel, 'Cluster Manager');
      // A rejection is now an outright rejection, never a send-back.
      expect(row('REGIONAL', 'REJECT').actionLabel, 'Rejected');
      // Historical rows from the retired first stage still read.
      expect(row('MANAGER', 'APPROVE').stageLabel, 'Project Manager');
    });
  });

  group('a filed cycle is frozen while the approver has it', () {
    // The backend refuses an upload in these states; the tiles must agree, or
    // the filer only finds out via a 409 after picking a file.
    test('files are editable only while the cycle is the filer\'s', () {
      expect(isEditableByFiler(SubmissionStatus.draft), isTrue);
      expect(isEditableByFiler(SubmissionStatus.rejected), isTrue);
      // With one approval stage, letting files change here would mean the
      // cluster manager approving evidence nobody reviewed.
      expect(isEditableByFiler(SubmissionStatus.submitted), isFalse);
      expect(isEditableByFiler(SubmissionStatus.managerApproved), isFalse);
      expect(isEditableByFiler(SubmissionStatus.approved), isFalse);
    });

    test('editable and awaiting-approval never overlap', () {
      for (final s in SubmissionStatus.values) {
        expect(
          isEditableByFiler(s) && isAwaitingApproval(s),
          isFalse,
          reason: '$s cannot be both the filer\'s and the approver\'s',
        );
      }
    });
  });

  group('home screen routes each role to its half of the flow', () {
    testWidgets('the project manager files cycles and has no review queue',
        (tester) async {
      await _pumpHome(tester, UserRole.manager);

      expect(tester.takeException(), isNull);
      expect(find.text('Monthly submission'), findsOneWidget);
      expect(find.text('Review queue'), findsNothing);
    });

    testWidgets('the cluster manager reviews and does not file',
        (tester) async {
      await _pumpHome(tester, UserRole.clusterManager);

      expect(tester.takeException(), isNull);
      expect(find.text('Review queue'), findsOneWidget);
      expect(find.text('Monthly submission'), findsNothing);
    });

    testWidgets('the site user still files', (tester) async {
      await _pumpHome(tester, UserRole.siteUser);

      expect(tester.takeException(), isNull);
      expect(find.text('Monthly submission'), findsOneWidget);
      expect(find.text('Review queue'), findsNothing);
    });

    testWidgets('admin keeps both halves', (tester) async {
      await _pumpHome(tester, UserRole.admin);

      expect(tester.takeException(), isNull);
      expect(find.text('Monthly submission'), findsOneWidget);
      expect(find.text('Review queue'), findsOneWidget);
    });

    testWidgets('Ops Excellence reviews only', (tester) async {
      await _pumpHome(tester, UserRole.opsExcellence);

      expect(tester.takeException(), isNull);
      expect(find.text('Review queue'), findsOneWidget);
      expect(find.text('Monthly submission'), findsNothing);
    });
  });

  group('one employee, several roles', () {
    test('the wire list is parsed, primary first', () {
      final u = AuthUser.fromJson({
        'id': 'u1',
        'name': 'Dual',
        'email': 'd@vistarlogitek.com',
        'username': 'dual',
        'role': 'MANAGER',
        'roles': ['MANAGER', 'CLUSTER_MANAGER'],
        'assignedProjectIds': ['p1'],
      });
      expect(u.roles, [UserRole.manager, UserRole.clusterManager]);
      // `role` still names one, for display and telemetry.
      expect(u.role, UserRole.manager);
      expect(u.has(UserRole.clusterManager), isTrue);
      expect(u.has(UserRole.admin), isFalse);
    });

    test('a backend without `roles` still yields a one-role user', () {
      // An older deploy sends `role` alone; the app must not end up role-less.
      final u = AuthUser.fromJson({
        'id': 'u1',
        'name': 'Solo',
        'email': 's@vistarlogitek.com',
        'username': 'solo',
        'role': 'SITE_USER',
      });
      expect(u.roles, [UserRole.siteUser]);
      expect(u.has(UserRole.siteUser), isTrue);
    });

    test('an unknown role name never becomes a held role', () {
      // Otherwise `has(UserRole.unknown)` would be true and a future role name
      // would silently read as a permission the user does not have.
      final u = AuthUser.fromJson({
        'id': 'u1',
        'name': 'Odd',
        'email': 'o@vistarlogitek.com',
        'username': 'odd',
        'role': 'SITE_USER',
        'roles': ['SITE_USER', 'SOMETHING_NEW'],
      });
      expect(u.roles, [UserRole.siteUser]);
      expect(u.has(UserRole.unknown), isFalse);
    });

    test('`roles` carrying only unknown names falls back to the primary', () {
      final u = AuthUser.fromJson({
        'id': 'u1',
        'name': 'Odd',
        'email': 'o@vistarlogitek.com',
        'username': 'odd',
        'role': 'OPS_EXCELLENCE',
        'roles': ['SOMETHING_NEW'],
      });
      expect(u.roles, [UserRole.opsExcellence]);
    });

    testWidgets('a project manager who is also cluster manager gets both tiles',
        (tester) async {
      // The whole point of multi-role: the union, not the primary role.
      await _pumpHomeWith(tester, [UserRole.manager, UserRole.clusterManager]);

      expect(tester.takeException(), isNull);
      expect(find.text('Monthly submission'), findsOneWidget);
      expect(find.text('Review queue'), findsOneWidget);
    });

    testWidgets('a secondary admin hat still unlocks the admin button',
        (tester) async {
      await _pumpHomeWith(tester, [UserRole.siteUser, UserRole.admin]);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Admin'), findsOneWidget);
    });

    testWidgets('a single-role site user gets no admin button', (tester) async {
      await _pumpHome(tester, UserRole.siteUser);

      expect(find.byTooltip('Admin'), findsNothing);
    });
  });

  group('nobody approves their own report', () {
    // Mirrors the server rule. The app hides the decision panel rather than
    // offering a button that can only come back 403.
    test('a submission knows who filed it', () {
      final s = _submission(submittedBy: 'u1');
      expect(s.wasFiledBy('u1'), isTrue);
      expect(s.wasFiledBy('u2'), isFalse);
      // Unknown either way is not a match — the server still refuses.
      expect(s.wasFiledBy(null), isFalse);
      expect(_submission(submittedBy: '').wasFiledBy(''), isFalse);
    });

    test('a backend that omits submittedBy claims nothing', () {
      final s = Submission.fromJson({
        'id': 's1',
        'projectId': 'p1',
        'month': '2026-10',
        'status': 'SUBMITTED',
        'items': const [],
      });
      expect(s.submittedById, isNull);
      expect(s.wasFiledBy('u1'), isFalse);
    });
  });
}
