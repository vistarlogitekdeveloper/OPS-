import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/secure_token_store.dart';
import 'api_config.dart';

const _kBackendKey = 'opsapp.api_base_url';

/// Seed for [backendUrlProvider]. Overridden in `main()` with the persisted
/// choice so the Dio providers can read the backend synchronously at startup.
final initialBackendUrlProvider = Provider<String>(
  (ref) => ApiConfig.buildTimeBaseUrl,
);

/// The backend the app is currently talking to. Switching rebuilds the Dio
/// clients, so no restart is needed.
class BackendUrlController extends Notifier<String> {
  @override
  String build() => ref.read(initialBackendUrlProvider);

  /// Points the app at [url]. Tokens are cleared first: a session issued by one
  /// deployment is meaningless to another, and leaving it behind would produce
  /// confusing 401s instead of a clean sign-in.
  Future<void> select(String url) async {
    final next = ApiConfig.normalize(url);
    if (next.isEmpty || next == state) return;

    await ref.read(secureTokenStoreProvider).clear();
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendKey, next);
  }

  /// Forgets the saved choice and returns to this build's default.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackendKey);
    await ref.read(secureTokenStoreProvider).clear();
    state = ApiConfig.buildTimeBaseUrl;
  }

  /// Reads the persisted choice. Called once from `main()` before the app runs.
  /// Never throws — a storage failure just falls back to the build default.
  static Future<String> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kBackendKey);
      if (saved == null || saved.trim().isEmpty) return ApiConfig.buildTimeBaseUrl;
      return ApiConfig.normalize(saved);
    } catch (_) {
      return ApiConfig.buildTimeBaseUrl;
    }
  }
}

final backendUrlProvider = NotifierProvider<BackendUrlController, String>(
  BackendUrlController.new,
);
