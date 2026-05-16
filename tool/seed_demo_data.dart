// Generates realistic dashboard-demo data:
//  - For 5 projects × last 6 months, upload one PDF to every category
//    (temporarily widening category whitelists), submit, approve, score with
//    a random distribution. Result: every chart has visible variation.
//
// Run: `dart run tool/seed_demo_data.dart`
// Idempotent — re-running tops up missing cycles only.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const _baseUrl = 'http://localhost:4000/api';
final _pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));
final _rng = Random(42);

Dio _client({String? bearer}) => Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Accept': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      },
      validateStatus: (s) => s != null && s < 500,
    ));

String _monthOffset(int monthsBack) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month - monthsBack, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

Future<int> main() async {
  print('Connecting…');
  final admin = _client();
  var r = await admin.post<dynamic>('/auth/login',
      data: {'username': 'admin', 'password': 'ChangeMe@123'});
  if (r.statusCode != 200) {
    print('FAIL: admin login (${r.statusCode}) — is the backend running?');
    return 1;
  }
  admin.options.headers['Authorization'] = 'Bearer ${(r.data as Map)['accessToken']}';

  final projs = ((await admin.get<dynamic>('/projects?pageSize=10')).data as Map)['items'] as List;
  final targets = projs.take(5).cast<Map>().toList();
  print('Target projects: ${targets.map((p) => p['code']).join(', ')}');

  final cats = ((await admin.get<dynamic>('/categories?pageSize=100')).data as Map)['items']
      as List;
  final categories = cats.cast<Map>().where((c) => c['isActive'] == true).toList();

  // Widen every category to accept PDF for the duration of the seed, then restore.
  final originalAllowed = <String, List<String>>{};
  for (final c in categories) {
    final list = (c['allowedFileTypes'] as List).cast<String>();
    originalAllowed[c['id'] as String] = list;
    if (!list.contains('PDF')) {
      await admin.patch<dynamic>('/categories/${c['id']}',
          data: {'allowedFileTypes': [...list, 'PDF']});
    }
  }

  try {
    final months = [for (int i = 5; i >= 0; i--) _monthOffset(i)];
    print('Months: ${months.join(', ')}');

    for (final p in targets) {
      final projectId = p['id'] as String;
      final code = p['code'] as String;
      for (final month in months) {
        print('-- $code $month');
        final cycle = await admin.get<dynamic>(
          '/submissions/cycle',
          queryParameters: {'projectId': projectId, 'month': month},
        );
        final existing = (cycle.data as Map)['submission'];
        if (existing != null && (existing as Map)['status'] == 'APPROVED') {
          print('   already approved — skip');
          continue;
        }

        // Upload to every category (using fresh bytes so dedupe still keys per category).
        String? subId;
        for (final c in categories) {
          final form = FormData.fromMap({
            'projectId': projectId,
            'month': month,
            'categoryId': c['id'],
            'file': MultipartFile.fromBytes(_pdfBytes, filename: '${c['id']}.pdf'),
          });
          final up = await admin.post<dynamic>('/submissions/upload', data: form);
          if (up.statusCode != 201) {
            print('   upload ${c['name']} -> ${up.statusCode}');
            continue;
          }
          subId = (((up.data as Map)['submission'] as Map)['id'] as String);
        }
        if (subId == null) continue;

        // Submit and approve.
        final sub = await admin.post<dynamic>('/submissions/$subId/submit');
        if (sub.statusCode != 200) {
          print('   submit failed: ${sub.statusCode} ${sub.data}');
          continue;
        }
        final dec = await admin.post<dynamic>('/submissions/$subId/decision',
            data: {'decision': 'APPROVE', 'comment': 'Demo data seed.'});
        if (dec.statusCode != 200) {
          print('   approve failed: ${dec.statusCode}');
          continue;
        }

        // Allocate marks: 60–100% of category max, jittered.
        final items = ((dec.data as Map)['submission'] as Map)['items'] as List;
        for (final i in items.cast<Map>()) {
          final cat = i['category'] as Map;
          final max = cat['maxMarks'] as int;
          final ratio = 0.6 + _rng.nextDouble() * 0.4;
          final awarded = (max * ratio).round().clamp(0, max);
          await admin.post<dynamic>(
            '/submissions/$subId/items/${i['id']}/score',
            data: {'awardedMarks': awarded},
          );
        }
      }
    }
    print('\nDemo data seeded for 5 projects × 6 months. Reload the dashboard in Chrome.');
    return 0;
  } finally {
    // Restore allow-lists.
    for (final entry in originalAllowed.entries) {
      await admin.patch<dynamic>('/categories/${entry.key}',
          data: {'allowedFileTypes': entry.value});
    }
  }
}
