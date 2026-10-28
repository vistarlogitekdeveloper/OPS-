import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_models.dart';

/// The two admin-triggered mails (backend: modules/mail).
enum MailKind { common, pending }

String roleToWire(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'ADMIN';
    case UserRole.manager:
      return 'MANAGER';
    case UserRole.clusterManager:
      return 'CLUSTER_MANAGER';
    case UserRole.siteUser:
      return 'SITE_USER';
    case UserRole.opsExcellence:
      return 'OPS_EXCELLENCE';
    case UserRole.unknown:
      return 'UNKNOWN';
  }
}

/// Live SMTP health from GET /mail/status.
class MailStatus {
  MailStatus({
    required this.transport,
    required this.configured,
    required this.verified,
    required this.schedulersEnabled,
    this.host,
    this.port,
    this.from,
    this.error,
  });

  /// 'relay' (server SMTP), 'org' (organisation's own server) or 'none'.
  final String transport;
  final bool configured;

  /// Login to the mail server succeeded just now; null when not attempted.
  final bool? verified;
  final bool schedulersEnabled;
  final String? host;
  final int? port;
  final String? from;
  final String? error;

  bool get healthy => configured && verified != false;

  factory MailStatus.fromJson(Map<String, dynamic> j) => MailStatus(
        transport: j['transport'] as String? ?? 'none',
        configured: j['configured'] as bool? ?? false,
        verified: j['verified'] as bool?,
        schedulersEnabled: j['schedulersEnabled'] as bool? ?? false,
        host: j['host'] as String?,
        port: (j['port'] as num?)?.toInt(),
        from: j['from'] as String?,
        error: j['error'] as String?,
      );
}

class PendingSite {
  PendingSite({required this.code, required this.name});
  final String code;
  final String name;

  factory PendingSite.fromJson(Map<String, dynamic> j) =>
      PendingSite(code: j['code'] as String, name: j['name'] as String);
}

class MailRecipient {
  MailRecipient({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.sites = const [],
  });

  final String userId;
  final String name;

  /// Null for the "no email address" list — shown, never sent to.
  final String? email;
  final UserRole role;
  final List<PendingSite> sites;

  factory MailRecipient.fromJson(Map<String, dynamic> j) => MailRecipient(
        userId: j['userId'] as String,
        name: j['name'] as String,
        email: j['email'] as String?,
        role: roleFromWire(j['role'] as String? ?? ''),
        sites: [
          for (final s in (j['sites'] as List? ?? const []))
            PendingSite.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// A template, pre-filled by the server, plus who it would go to.
class MailDraft {
  MailDraft({
    required this.kind,
    required this.subject,
    required this.body,
    required this.placeholders,
    required this.recipients,
    required this.noEmail,
    this.month,
    this.monthLabel,
  });

  final MailKind kind;
  final String subject;
  final String body;
  final List<String> placeholders;
  final List<MailRecipient> recipients;
  final List<MailRecipient> noEmail;

  /// pending only: YYYY-MM and its label ("September 2026").
  final String? month;
  final String? monthLabel;

  factory MailDraft.fromJson(MailKind kind, Map<String, dynamic> j) {
    final t = j['template'] as Map<String, dynamic>;
    List<MailRecipient> list(String key) => [
          for (final r in (j[key] as List? ?? const []))
            MailRecipient.fromJson(r as Map<String, dynamic>),
        ];
    return MailDraft(
      kind: kind,
      subject: t['subject'] as String,
      body: t['body'] as String,
      placeholders: [for (final p in (t['placeholders'] as List? ?? const [])) p as String],
      recipients: list('recipients'),
      noEmail: list('noEmail'),
      month: j['month'] as String?,
      monthLabel: j['monthLabel'] as String?,
    );
  }
}

class SendResult {
  SendResult({required this.name, required this.email, required this.ok, this.error});
  final String name;
  final String email;
  final bool ok;
  final String? error;

  factory SendResult.fromJson(Map<String, dynamic> j) => SendResult(
        name: j['name'] as String,
        email: j['email'] as String,
        ok: j['ok'] as bool,
        error: j['error'] as String?,
      );
}

class SendOutcome {
  SendOutcome({required this.sent, required this.failed, required this.results});
  final int sent;
  final int failed;
  final List<SendResult> results;

  factory SendOutcome.fromJson(Map<String, dynamic> j) => SendOutcome(
        sent: (j['sent'] as num).toInt(),
        failed: (j['failed'] as num).toInt(),
        results: [
          for (final r in (j['results'] as List? ?? const []))
            SendResult.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class EmailsRepository {
  EmailsRepository(this._dio);
  final Dio _dio;

  Future<MailStatus> status() async {
    // Connects and logs in to the mail server, which can take a while.
    final res = await _dio.get<Map<String, dynamic>>(
      '/mail/status',
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return MailStatus.fromJson(res.data!['mail'] as Map<String, dynamic>);
  }

  Future<MailDraft> commonDraft(Set<UserRole> roles) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/mail/templates/common',
      queryParameters: {'roles': roles.map(roleToWire).join(',')},
    );
    return MailDraft.fromJson(MailKind.common, res.data!);
  }

  /// [month] is YYYY-MM; null lets the server pick last month.
  Future<MailDraft> pendingDraft(String? month) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/mail/templates/pending',
      queryParameters: {'month': ?month},
    );
    return MailDraft.fromJson(MailKind.pending, res.data!);
  }

  Future<SendOutcome> send({
    required MailKind kind,
    required String subject,
    required String body,
    Set<UserRole>? roles,
    String? month,
    Set<String> excludeUserIds = const {},
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/mail/send',
      data: {
        'kind': kind.name,
        'subject': subject,
        'body': body,
        if (kind == MailKind.common) 'roles': roles!.map(roleToWire).toList(),
        if (kind == MailKind.pending) 'month': month,
        'excludeUserIds': excludeUserIds.toList(),
      },
      // One SMTP session per recipient — a long list needs well over the
      // default 30s before the server can answer with the results.
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return SendOutcome.fromJson(res.data!);
  }
}

final emailsRepositoryProvider =
    Provider((ref) => EmailsRepository(ref.watch(apiClientProvider)));

final mailStatusProvider = FutureProvider.autoDispose<MailStatus>(
    (ref) => ref.watch(emailsRepositoryProvider).status());
