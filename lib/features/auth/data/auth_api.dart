import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi({required Dio unauth, required Dio authed})
      : _unauth = unauth,
        _authed = authed;

  final Dio _unauth;
  final Dio _authed;

  Future<AuthSession> login({required String username, required String password}) async {
    final res = await _unauth.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return AuthSession.fromJson(res.data!);
  }

  Future<void> logout({required String refreshToken}) async {
    await _unauth.post<void>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
      options: Options(validateStatus: (s) => s == null || s == 204 || (s >= 200 && s < 300)),
    );
  }

  Future<AuthUser> me() async {
    final res = await _authed.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<void> forgotPassword({required String identifier}) async {
    await _unauth.post<void>(
      '/auth/forgot-password',
      data: {'identifier': identifier},
      options: Options(validateStatus: (s) => s == null || s == 204 || (s >= 200 && s < 300)),
    );
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(
    unauth: ref.watch(unauthenticatedDioProvider),
    authed: ref.watch(apiClientProvider),
  );
});
