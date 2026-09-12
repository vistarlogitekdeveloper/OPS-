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

AuthState _sessionAs(UserRole role) => AuthState(
      status: AuthStatus.authenticated,
      user: AuthUser(
        id: 'u1',
        name: 'Test User',
        email: 'test@vistarlogitek.com',
        username: 'test',
        role: role,
        assignedProjectIds: const ['p1'],
        isActive: true,
      ),
    );

Widget _home(UserRole role) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuth(_sessionAs(role))),
        // The badge would otherwise hit the network.
        pendingReviewCountProvider
            .overrideWith((ref) async => PendingReviewCount.empty),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
    );

Future<void> _pumpHome(WidgetTester tester, UserRole role) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_home(role));
  await tester.pumpAndSettle();
}

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
}
