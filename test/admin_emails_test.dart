// Admin → Emails: the SMTP status card and the two hand-triggered mails.
// The repository is faked, so this pins what the screen sends to the backend:
// the admin's edited text, the chosen roles / month, and whom they un-ticked.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/admin/emails/data/emails_repository.dart';
import 'package:opsapp/features/admin/emails/presentation/emails_screen.dart';
import 'package:opsapp/features/admin/presentation/admin_shell.dart';
import 'package:opsapp/features/auth/application/auth_controller.dart';
import 'package:opsapp/features/auth/data/auth_models.dart';

class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: 'u1',
          name: 'Admin',
          email: 'admin@vistarlogitek.com',
          username: 'admin',
          roles: [UserRole.admin],
          assignedProjectIds: [],
          isActive: true,
        ),
      );
}

class _FakeRepo extends EmailsRepository {
  _FakeRepo({this.smtpOk = true}) : super(Dio());
  final bool smtpOk;
  final sends = <Map<String, Object?>>[];

  @override
  Future<MailStatus> status() async => smtpOk
      ? MailStatus(
          transport: 'relay',
          configured: true,
          verified: true,
          schedulersEnabled: false,
          host: 'smtp.office365.com',
          port: 587,
          from: 'OpsApp <ops@vistarlogitek.com>')
      : MailStatus(
          transport: 'relay',
          configured: true,
          verified: false,
          schedulersEnabled: true,
          host: 'smtp.office365.com',
          port: 587,
          error: '535 5.7.139 Authentication unsuccessful');

  @override
  Future<MailDraft> commonDraft(Set<UserRole> roles) async => MailDraft(
        kind: MailKind.common,
        subject: 'OpsApp — important update',
        body: 'Hi {{name}},\n\n[Write your message here]\n\n— OpsApp',
        placeholders: const ['{{name}}'],
        recipients: [
          MailRecipient(userId: 'a', name: 'Asha', email: 'asha@x.com', role: UserRole.siteUser),
          MailRecipient(userId: 'b', name: 'Bala', email: 'bala@x.com', role: UserRole.manager),
          MailRecipient(userId: 'c', name: 'Chitra', email: 'chitra@x.com', role: UserRole.admin),
        ].where((r) => roles.contains(r.role)).toList(),
        noEmail: [MailRecipient(userId: 'd', name: 'Dev', email: null, role: UserRole.siteUser)],
      );

  @override
  Future<MailDraft> pendingDraft(String? month) async => MailDraft(
        kind: MailKind.pending,
        subject: 'Reminder: {{month}} ops report pending',
        body: 'Hi {{name}},\n\n{{sites}}\n\n— OpsApp',
        placeholders: const ['{{name}}', '{{month}}', '{{sites}}', '{{siteCount}}'],
        month: month ?? '2026-09',
        monthLabel: 'September 2026',
        recipients: [
          MailRecipient(
            userId: 'a',
            name: 'Asha',
            email: 'asha@x.com',
            role: UserRole.siteUser,
            sites: [PendingSite(code: 'PUN-01', name: 'Pune Plant')],
          ),
        ],
        noEmail: const [],
      );

  @override
  Future<SendOutcome> send({
    required MailKind kind,
    required String subject,
    required String body,
    Set<UserRole>? roles,
    String? month,
    Set<String> excludeUserIds = const {},
  }) async {
    sends.add({
      'kind': kind,
      'subject': subject,
      'body': body,
      'roles': roles == null ? null : {...roles},
      'month': month,
      'exclude': {...excludeUserIds},
    });
    return SendOutcome(sent: 1, failed: 1, results: [
      SendResult(name: 'Asha', email: 'asha@x.com', ok: true),
      SendResult(name: 'Chitra', email: 'chitra@x.com', ok: false, error: '550 mailbox unavailable'),
    ]);
  }
}

Widget _app(_FakeRepo repo) {
  final router = GoRouter(initialLocation: '/admin/emails', routes: [
    ShellRoute(
      builder: (_, _, child) => AdminShell(child: child),
      routes: [GoRoute(path: '/admin/emails', builder: (_, _) => const EmailsScreen())],
    ),
  ]);
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_FakeAuth.new),
      emailsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('opens on the app template with SMTP status and recipients', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Emails'), findsWidgets); // the admin tab
    expect(find.text('Connected — emails can be sent'), findsOneWidget);
    expect(find.text('Automatic monthly reminders are off'), findsOneWidget);
    // Template is pre-filled and editable.
    expect(find.widgetWithText(TextField, 'OpsApp — important update'), findsOneWidget);
    expect(find.textContaining('[Write your message here]'), findsWidgets);
    expect(find.text('Send to 3 people'), findsOneWidget);
    expect(find.textContaining('1 without an email address'), findsOneWidget);
  });

  testWidgets('sends the edited text, chosen roles and un-ticked recipients', (tester) async {
    _tall(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Drop the Admin role → Chitra leaves the list.
    await tester.tap(find.widgetWithText(FilterChip, roleLabel(UserRole.admin)));
    await tester.pumpAndSettle();
    expect(find.text('Send to 2 people'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'OpsApp — important update'), 'Audit on {{name}}');
    final body = find.byWidgetPredicate((w) => w is TextField && (w.minLines ?? 1) >= 10);
    await tester.enterText(body, 'Hi {{name}},\n\nSafety audit on Monday.');

    // Un-tick Bala.
    await tester.tap(find.textContaining('Recipients — 2 of 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bala · ${roleLabel(UserRole.manager)}'));
    await tester.pumpAndSettle();
    expect(find.text('Send to 1 person'), findsOneWidget);

    // Live preview follows the edit, filled for the first recipient.
    await tester.tap(find.text('Preview for Asha'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Safety audit on Monday.', findRichText: true), findsWidgets);
    expect(find.textContaining('Audit on Asha', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Send to 1 person'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();

    expect(repo.sends, hasLength(1));
    final s = repo.sends.single;
    expect(s['kind'], MailKind.common);
    expect(s['subject'], 'Audit on {{name}}');
    expect(s['body'], 'Hi {{name}},\n\nSafety audit on Monday.');
    expect((s['roles'] as Set).contains(UserRole.admin), isFalse);
    expect(s['exclude'], {'b'});

    // Per-recipient outcome, failures named with the server's reason.
    expect(find.text('Sent 1 of 2'), findsOneWidget);
    expect(find.text('550 mailbox unavailable'), findsOneWidget);
  });

  testWidgets('pending tab: last month, each person\'s own sites', (tester) async {
    _tall(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pending submissions'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Send to 1 person'), findsOneWidget);

    await tester.tap(find.text('Preview for Asha'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PUN-01 — Pune Plant', findRichText: true), findsOneWidget);
    expect(find.textContaining('Reminder: September 2026', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Send to 1 person'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(repo.sends.single['kind'], MailKind.pending);
    expect(repo.sends.single['month'], '2026-09');
  });

  testWidgets('a failing mail server is shown with its error', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_FakeRepo(smtpOk: false)));
    await tester.pumpAndSettle();
    expect(find.textContaining('emails are NOT being sent'), findsOneWidget);
    expect(find.textContaining('535 5.7.139 Authentication unsuccessful'), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(375, 812), Size(768, 1024)]) {
    testWidgets('renders without overflow at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = prev);

      await tester.pumpWidget(_app(_FakeRepo()));
      await tester.pumpAndSettle();
      // Phones get the short tab labels.
      await tester.tap(find.text(size.width < 520 ? 'Pending' : 'Pending submissions'));
      await tester.pumpAndSettle();

      FlutterError.onError = prev;
      expect(errors.map((e) => e.exceptionAsString()), isEmpty);
    });
  }
}




