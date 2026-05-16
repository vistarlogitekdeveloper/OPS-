import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? errorMessage, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const anonymous = AuthState(status: AuthStatus.unauthenticated);
}

class AuthController extends Notifier<AuthState> {
  late final AuthApi _api;
  late final SecureTokenStore _store;

  @override
  AuthState build() {
    _api = ref.watch(authApiProvider);
    _store = ref.watch(secureTokenStoreProvider);

    // React to the interceptor wiping tokens.
    ref.listen<int>(authSessionInvalidatedProvider, (_, _) {
      state = AuthState.anonymous;
    });

    // Kick off boot — restore session if tokens are already on disk.
    Future.microtask(_restore);
    return AuthState.unknown;
  }

  Future<void> _restore() async {
    TokenPair? pair;
    try {
      pair = await _store.read();
    } catch (_) {
      // Secure storage unavailable (e.g. widget test, missing platform stub).
      state = AuthState.anonymous;
      return;
    }
    if (pair == null) {
      state = AuthState.anonymous;
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      try {
        await _store.clear();
      } catch (_) {}
      state = AuthState.anonymous;
    }
  }

  Future<bool> login({required String username, required String password}) async {
    state = state.copyWith(clearError: true);
    try {
      final session = await _api.login(username: username, password: password);
      await _store.write(TokenPair(access: session.accessToken, refresh: session.refreshToken));
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _messageFor(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Unexpected error: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final pair = await _store.read();
    try {
      if (pair != null) {
        await _api.logout(refreshToken: pair.refresh);
      }
    } catch (_) {
      // Best-effort — clear local state regardless.
    }
    await _store.clear();
    state = AuthState.anonymous;
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  static String _messageFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Incorrect username or password.';
    if (code == 400) return 'Please check the form and try again.';
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Is the backend running?';
    }
    return 'Login failed (${code ?? e.type.name}). Please try again.';
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
