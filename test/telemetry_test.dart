import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opsapp/core/telemetry/telemetry.dart';

void main() {
  // The backend keys every record by a cuid (prisma @default(cuid())).
  const cuid = 'cm1x9z8k70000abcdxyz12345';
  const cuid2 = 'clz0q4wq30002mn7c1r5e8h2k';
  const uuid = '7f3c2a10-1b2c-4d5e-8f90-a1b2c3d4e5f6';

  test('screen names carry no record ids', () {
    expect(Telemetry.routePattern('/'), '/');
    expect(Telemetry.routePattern('/submission/picker'), '/submission/picker');
    expect(Telemetry.routePattern('/admin/projects'), '/admin/projects');
    expect(Telemetry.routePattern('/review/$cuid'), '/review/:id');
    expect(Telemetry.routePattern('/sites/$cuid2'), '/sites/:id');
    expect(Telemetry.routePattern('/sites/$uuid?month=2026-09'), '/sites/:id');
    expect(Telemetry.routePattern('/review/42'), '/review/:id');
  });

  test('a cuid with no digit in it, codes and months are replaced too', () {
    expect(Telemetry.routePattern('/review/cabcdefghijklmnopqrstuvwx'), '/review/:id');
    expect(Telemetry.routePattern('/sites/PUN-WH-01'), '/sites/:ref');
    expect(Telemetry.routePattern('/sites/2026-09'), '/sites/:ref');
    expect(Telemetry.routePattern('/sites/a1'), '/sites/:ref');
  });

  test('API paths keep their shape and lose their ids', () {
    expect(Telemetry.routePattern('/submissions/$cuid/items/$cuid2/score'),
        '/submissions/:id/items/:id/score');
    expect(Telemetry.routePattern('/submissions/items/$cuid/download'), '/submissions/items/:id/download');
    expect(Telemetry.routePattern('/submissions/pending-count'), '/submissions/pending-count');
    expect(Telemetry.routePattern('/exports/monthly.pdf?month=2026-09&projectId=$cuid'), '/exports/monthly.pdf');
    expect(Telemetry.routePattern('https://api.example.com/api/v1/ops-backend/api/projects/$cuid'),
        '/api/v1/ops-backend/api/projects/:id');
  });

  test('the monthly cycle and admin writes are named from successful calls', () {
    expect(Telemetry.actionFor('POST', '/submissions/upload'), 'report_uploaded');
    expect(Telemetry.actionFor('POST', '/submissions/$cuid/submit'), 'submission_filed');
    expect(Telemetry.actionFor('POST', '/submissions/$cuid/decision'), 'submission_reviewed');
    expect(Telemetry.actionFor('POST', '/submissions/$cuid/items/$cuid2/score'), 'item_scored');
    expect(Telemetry.actionFor('POST', '/projects'), 'project_created');
    expect(Telemetry.actionFor('PATCH', '/projects/$cuid'), 'project_updated');
    expect(Telemetry.actionFor('DELETE', '/projects/$cuid'), 'project_deactivated');
    expect(Telemetry.actionFor('POST', '/categories'), 'category_created');
    expect(Telemetry.actionFor('PATCH', '/categories/$cuid'), 'category_updated');
    expect(Telemetry.actionFor('DELETE', '/categories/$cuid'), 'category_deactivated');
    expect(Telemetry.actionFor('post', '/users'), 'user_created');
    expect(Telemetry.actionFor('PATCH', '/users/$cuid'), 'user_updated');
    expect(Telemetry.actionFor('DELETE', '/users/$cuid'), 'user_deactivated');
    expect(Telemetry.actionFor('POST', '/users/$cuid/password'), 'user_password_set');
    expect(Telemetry.actionFor('POST', '/auth/forgot-password'), 'password_reset_requested');
  });

  test('reads, exports, sign-in, refresh and unknown paths are not reported', () {
    expect(Telemetry.actionFor('GET', '/submissions/queue'), isNull);
    expect(Telemetry.actionFor('GET', '/submissions/$cuid'), isNull);
    expect(Telemetry.actionFor('GET', '/submissions/cycle'), isNull);
    expect(Telemetry.actionFor('GET', '/exports/monthly.xlsx'), isNull);
    expect(Telemetry.actionFor('GET', '/projects'), isNull);
    expect(Telemetry.actionFor('PATCH', '/submissions/upload'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/login'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/refresh'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/logout'), isNull);
    expect(Telemetry.actionFor('POST', '/audit'), isNull);
  });

  test('off without ET_APP_ID and ET_WRITE_KEY (the default build); calls are safe', () async {
    expect(Telemetry.enabled, isFalse);
    await Telemetry.init(apiBaseUrl: 'https://api.example.com/api/v1/ops-backend');
    Telemetry.screen('/review');
    Telemetry.track('report_uploaded');
    Telemetry.error('api_error', {'endpoint': '/submissions/upload', 'method': 'POST'});
    Telemetry.zoneError(StateError('x'));
    Telemetry.signedIn(userId: 'u1', role: 'manager');
    Telemetry.signedOut();
  });

  test('the interceptor changes nothing about a request or its outcome', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid'))
      ..httpClientAdapter = _Answer()
      ..interceptors.add(TelemetryInterceptor());
    final ok = await dio.post<dynamic>('/submissions/upload', data: {'x': 1});
    expect(ok.statusCode, 201);
    expect((ok.data as Map)['ok'], isTrue);
    await expectLater(
      dio.post<dynamic>('/submissions/$cuid/submit'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
  });
}

/// Answers 201 for an upload and 503 for anything else, with no network.
class _Answer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final created = options.path == '/submissions/upload';
    return ResponseBody.fromString(
      jsonEncode({'ok': created}),
      created ? 201 : 503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
