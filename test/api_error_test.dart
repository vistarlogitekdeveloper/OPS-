import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/core/errors/api_error.dart';

DioException _withStatus(int status, {String? serverMessage}) {
  final req = RequestOptions(path: '/submissions/upload');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: req,
      statusCode: status,
      data: serverMessage == null
          ? null
          : {
              'error': {'code': 'FORBIDDEN', 'message': serverMessage}
            },
    ),
  );
}

void main() {
  test('the server message is what the user is shown', () {
    final err = ApiError.from(
      _withStatus(403, serverMessage: 'Only site users and project managers can upload submissions'),
    );
    expect(err.status, 403);
    expect(err.code, 'FORBIDDEN');
    expect(
      err.message,
      'Only site users and project managers can upload submissions',
    );
  });

  group('offering a retry', () {
    test('a refusal is the server\'s settled answer — no retry', () {
      // Re-sending these returns the same thing every time, so a Retry button
      // only invites the user to hit the same wall.
      for (final status in [400, 401, 403, 404, 409, 413, 422]) {
        expect(
          ApiError.from(_withStatus(status)).isRetryable,
          isFalse,
          reason: '$status should not offer a retry',
        );
      }
    });

    test('server faults and explicit try-agains are retryable', () {
      for (final status in [500, 502, 503, 504, 408, 429]) {
        expect(
          ApiError.from(_withStatus(status)).isRetryable,
          isTrue,
          reason: '$status should offer a retry',
        );
      }
    });

    test('no response at all is retryable', () {
      final req = RequestOptions(path: '/submissions/upload');
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        final err = ApiError.from(
          DioException(requestOptions: req, type: type),
        );
        expect(err.status, isNull);
        expect(err.isRetryable, isTrue, reason: '$type should offer a retry');
      }
    });
  });
}
