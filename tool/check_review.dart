// Phase 6 end-to-end check.
// Drives the full review lifecycle: admin uploads to every active category
// for a fresh cycle, submits for approval, a manager approves, then an
// Ops Excellence user allocates marks per item. Verifies state machine,
// role guards, and totalScore aggregation.
//
// Run: `dart run tool/check_review.dart`
// Delete this file when Phase 6 is signed off.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const _baseUrl = 'https://ops-backend-eqqd.onrender.com/api';
final _pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));

Dio _client({String? bearer}) => Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Accept': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      },
      validateStatus: (s) => s != null && s < 500,
    ));

Future<int> main() async {
  final admin = _client();

  print('== 1. login admin ==');
  var r = await admin.post<dynamic>('/auth/login',
      data: {'username': 'admin', 'password': 'ChangeMe@123'});
  if (r.statusCode != 200) return _fail('admin login: ${r.statusCode}');
  final adminTok = (r.data as Map)['accessToken'] as String;
  admin.options.headers['Authorization'] = 'Bearer $adminTok';

  print('== 2. provision manager + ops_excellence + site users ==');
  // Pick first project for site user assignment.
  final projects = (await admin.get<dynamic>('/projects?pageSize=1')).data as Map;
  final project = (projects['items'] as List).first as Map;
  final projectId = project['id'] as String;
  print('  project=${project['code']}');

  Future<Map<String, dynamic>> ensureUser(Map<String, dynamic> body) async {
    final res = await admin.post<dynamic>('/users', data: body);
    if (res.statusCode == 201) return (res.data as Map)['user'] as Map<String, dynamic>;
    if (res.statusCode == 409) {
      // Already exists; reset password and look up.
      final list = await admin.get<dynamic>(
        '/users',
        queryParameters: {'search': body['username']},
      );
      final found = ((list.data as Map)['items'] as List)
          .cast<Map>()
          .firstWhere((u) => u['username'] == body['username']);
      // Reactivate if needed.
      if (!(found['isActive'] as bool? ?? true)) {
        await admin.patch<dynamic>('/users/${found['id']}', data: {'isActive': true});
      }
      await admin.post<dynamic>('/users/${found['id']}/password',
          data: {'newPassword': body['password']});
      return found.cast<String, dynamic>();
    }
    throw 'create user ${body['username']}: ${res.statusCode} ${res.data}';
  }

  final manager = await ensureUser({
    'name': 'M One',
    'email': 'm.one@example.com',
    'username': 'm_one',
    'password': 'ChangeMe@123',
    'role': 'MANAGER',
    'assignedProjectIds': [projectId],
  });
  // Make sure the assignment is current (in case the user existed but unassigned).
  await admin.patch<dynamic>('/users/${manager['id']}',
      data: {'assignedProjectIds': [projectId], 'isActive': true});

  final opsEx = await ensureUser({
    'name': 'Ops One',
    'email': 'ops.one@example.com',
    'username': 'ops_one',
    'password': 'ChangeMe@123',
    'role': 'OPS_EXCELLENCE',
    'assignedProjectIds': <String>[],
  });

  Future<String> loginAs(String username, String password) async {
    final c = _client();
    final res = await c.post<dynamic>('/auth/login',
        data: {'username': username, 'password': password});
    if (res.statusCode != 200) {
      throw 'login $username: ${res.statusCode} ${res.data}';
    }
    return (res.data as Map)['accessToken'] as String;
  }

  final managerTok = await loginAs('m_one', 'ChangeMe@123');
  final opsTok = await loginAs('ops_one', 'ChangeMe@123');
  final mgr = _client(bearer: managerTok);
  final ops = _client(bearer: opsTok);
  print('  manager=${manager['username']} opsEx=${opsEx['username']}');

  print('== 3. admin uploads to every active category (fresh cycle) ==');
  const month = '2099-02';
  final cats = (await admin.get<dynamic>('/categories?pageSize=100')).data as Map;
  final categories = (cats['items'] as List)
      .cast<Map>()
      .where((c) => c['isActive'] == true)
      .toList();
  String? subId;
  for (final c in categories) {
    final form = FormData.fromMap({
      'projectId': projectId,
      'month': month,
      'categoryId': c['id'],
      'file': MultipartFile.fromBytes(_pdfBytes, filename: 'fixture.pdf'),
    });
    // Skip categories that don't include PDF in their whitelist.
    final allowed = (c['allowedFileTypes'] as List).cast<String>();
    if (!allowed.contains('PDF')) {
      // SLA Report is EXCEL only — upload a tiny valid xlsx? skip for fixture simplicity.
      print('  skip ${c['name']} (PDF not allowed)');
      continue;
    }
    final res = await admin.post<dynamic>('/submissions/upload', data: form);
    if (res.statusCode != 201) return _fail('upload to ${c['name']}: ${res.statusCode} ${res.data}');
    subId = ((res.data as Map)['submission'] as Map)['id'] as String;
  }
  if (subId == null) return _fail('no submission created');
  print('  submission=$subId');

  print('== 4. submit incomplete (SLA missing) — expect 400 ==');
  r = await admin.post<dynamic>('/submissions/$subId/submit');
  if (r.statusCode != 400) return _fail('expected 400 incomplete, got ${r.statusCode}');

  // Patch SLA Report category to allow PDF temporarily so the fixture can complete.
  final sla = categories.firstWhere((c) => c['name'] == 'SLA Report');
  final originalAllowed = (sla['allowedFileTypes'] as List).cast<String>();
  await admin.patch<dynamic>('/categories/${sla['id']}',
      data: {'allowedFileTypes': ['EXCEL', 'PDF']});
  try {
    final form = FormData.fromMap({
      'projectId': projectId,
      'month': month,
      'categoryId': sla['id'],
      'file': MultipartFile.fromBytes(_pdfBytes, filename: 'sla.pdf'),
    });
    r = await admin.post<dynamic>('/submissions/upload', data: form);
    if (r.statusCode != 201) return _fail('SLA upload: ${r.statusCode}');

    print('== 5. submit complete ==');
    r = await admin.post<dynamic>('/submissions/$subId/submit');
    if (r.statusCode != 200) return _fail('submit: ${r.statusCode} ${r.data}');
    var sub = (r.data as Map)['submission'] as Map;
    if (sub['status'] != 'SUBMITTED') return _fail('expected SUBMITTED, got ${sub['status']}');
    print('  submission status=SUBMITTED');

    print('== 6. site user cannot decide (manager-only) — expect 403 ==');
    // Use a fresh non-privileged login: re-use ops_one which is OPS_EXCELLENCE
    // (not a manager) to verify the manager guard.
    r = await ops.post<dynamic>('/submissions/$subId/decision',
        data: {'decision': 'APPROVE'});
    if (r.statusCode != 403) return _fail('expected 403 for ops decision, got ${r.statusCode}');

    print('== 7. manager queue lists this submission ==');
    r = await mgr.get<dynamic>('/submissions/queue');
    if (r.statusCode != 200) return _fail('queue: ${r.statusCode}');
    final queueItems = (r.data as Map)['items'] as List;
    final found = queueItems.cast<Map>().any((s) => s['id'] == subId);
    if (!found) return _fail('manager queue does not include $subId');
    print('  queue has ${queueItems.length} item(s)');

    print('== 8. manager approves ==');
    r = await mgr.post<dynamic>('/submissions/$subId/decision',
        data: {'decision': 'APPROVE', 'comment': 'Looks good.'});
    if (r.statusCode != 200) return _fail('approve: ${r.statusCode} ${r.data}');
    sub = (r.data as Map)['submission'] as Map;
    if (sub['status'] != 'APPROVED') return _fail('expected APPROVED, got ${sub['status']}');
    final approvedItems = sub['items'] as List;
    final allApproved = approvedItems.every((i) => (i as Map)['status'] == 'APPROVED');
    if (!allApproved) return _fail('not all items APPROVED after approve');
    print('  submission=APPROVED, items all APPROVED, totalScore=${sub['totalScore']}');

    print('== 9. cannot decide twice (already APPROVED) — expect 409 ==');
    r = await mgr.post<dynamic>('/submissions/$subId/decision',
        data: {'decision': 'REJECT'});
    if (r.statusCode != 409) return _fail('expected 409, got ${r.statusCode}');

    print('== 10. ops_excellence allocates marks per item ==');
    int expectedTotal = 0;
    for (final i in approvedItems.cast<Map>()) {
      final cat = i['category'] as Map;
      final marks = (cat['maxMarks'] as int);
      r = await ops.post<dynamic>(
        '/submissions/$subId/items/${i['id']}/score',
        data: {'awardedMarks': marks},
      );
      if (r.statusCode != 200) {
        return _fail('score ${cat['name']}: ${r.statusCode} ${r.data}');
      }
      expectedTotal += marks;
    }
    sub = (r.data as Map)['submission'] as Map;
    if (sub['totalScore'] != expectedTotal) {
      return _fail('totalScore=${sub['totalScore']}, expected $expectedTotal');
    }
    print('  totalScore=${sub['totalScore']} (expected $expectedTotal)');

    print('== 11. marks over category max — expect 400 ==');
    final firstItem = approvedItems.first as Map;
    final maxMarks = ((firstItem['category'] as Map)['maxMarks'] as int);
    r = await ops.post<dynamic>(
      '/submissions/$subId/items/${firstItem['id']}/score',
      data: {'awardedMarks': maxMarks + 1},
    );
    if (r.statusCode != 400) return _fail('expected 400 on overshoot, got ${r.statusCode}');

    print('== 12. manager can no longer score (Ops-only) — expect 403 ==');
    r = await mgr.post<dynamic>(
      '/submissions/$subId/items/${firstItem['id']}/score',
      data: {'awardedMarks': 0},
    );
    if (r.statusCode != 403) return _fail('expected 403 for manager score, got ${r.statusCode}');

    print('\nPhase 6 backend end-to-end checks passed.');
    return 0;
  } finally {
    // Always restore SLA allow-list.
    await admin.patch<dynamic>('/categories/${sla['id']}',
        data: {'allowedFileTypes': originalAllowed});
  }
}

int _fail(String why) {
  print('FAIL: $why');
  return 1;
}
