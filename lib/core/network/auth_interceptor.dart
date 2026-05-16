import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

/// Attaches the access token to every outgoing request and, on 401, transparently
/// refreshes the pair and retries the original request once. Concurrent 401s share
/// a single in-flight refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.refreshClient,
    required this.onTokensCleared,
  });

  final SecureTokenStore tokenStore;

  /// A Dio without this interceptor — used to call `/auth/refresh` without recursing.
  final Dio refreshClient;

  /// Called when refresh fails terminally so the app can surface a login prompt.
  final Future<void> Function() onTokensCleared;

  Completer<TokenPair?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_shouldSkipAuth(options)) return handler.next(options);
    final pair = await tokenStore.read();
    if (pair != null) {
      options.headers['Authorization'] = 'Bearer ${pair.access}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final request = err.requestOptions;

    final isAuthError = response?.statusCode == 401;
    final alreadyRetried = request.extra['__opsapp_retry__'] == true;
    final isRefreshCall = request.path.contains('/auth/refresh');

    if (!isAuthError || alreadyRetried || isRefreshCall || _shouldSkipAuth(request)) {
      return handler.next(err);
    }

    final refreshed = await _refreshTokens();
    if (refreshed == null) {
      await onTokensCleared();
      return handler.next(err);
    }

    request.headers['Authorization'] = 'Bearer ${refreshed.access}';
    request.extra['__opsapp_retry__'] = true;
    try {
      final retry = await refreshClient.fetch(request);
      return handler.resolve(retry);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<TokenPair?> _refreshTokens() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<TokenPair?>();
    _refreshing = completer;
    try {
      final current = await tokenStore.read();
      if (current == null) {
        completer.complete(null);
        return null;
      }
      final res = await refreshClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refresh},
      );
      final data = res.data;
      if (data == null) {
        completer.complete(null);
        return null;
      }
      final pair = TokenPair(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      await tokenStore.write(pair);
      completer.complete(pair);
      return pair;
    } catch (_) {
      await tokenStore.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshing = null;
    }
  }

  static bool _shouldSkipAuth(RequestOptions options) {
    return options.extra['__opsapp_skip_auth__'] == true;
  }
}
