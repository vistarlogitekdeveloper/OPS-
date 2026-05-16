import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_store.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';

/// Bare Dio used by the auth flow itself (no auth interceptor — would recurse
/// during refresh). Use this for `/auth/login`, `/auth/refresh`, and the initial
/// `/api/health` probe.
final unauthenticatedDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiRoot,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    contentType: 'application/json',
    responseType: ResponseType.json,
  ));
  return dio;
});

/// Authenticated Dio — attaches Bearer token, transparently refreshes on 401.
/// Use this for everything except auth-flow calls.
final apiClientProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  final unauth = ref.watch(unauthenticatedDioProvider);

  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiRoot,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    contentType: 'application/json',
    responseType: ResponseType.json,
  ));

  dio.interceptors.add(AuthInterceptor(
    tokenStore: tokenStore,
    refreshClient: unauth,
    onTokensCleared: () async {
      // Signal that the user must re-authenticate. The auth controller listens
      // for token clears via SecureTokenStore + its own poll on app start;
      // for explicit notification we trip the cleared notifier below.
      ref.read(authSessionInvalidatedProvider.notifier).state++;
    },
  ));

  return dio;
});

/// Incrementing counter the auth controller can watch to know when the
/// interceptor wiped tokens (e.g. refresh failed). Bumped from the interceptor.
final authSessionInvalidatedProvider = StateProvider<int>((ref) => 0);
