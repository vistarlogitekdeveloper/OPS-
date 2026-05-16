/// Backend base URL.
///
/// Resolution order:
///   1. `--dart-define=API_BASE_URL=...` (highest precedence — use this for
///      local dev against a local backend or a Cloudflare tunnel).
///   2. Default — the deployed production backend, used by every platform
///      (web, Android, iOS, desktop) so behaviour is identical everywhere.
///
/// Provide the ORIGIN only (no trailing `/api`); `apiRoot` appends `/api`.
/// Local dev example (run a local backend on :4000, or use dev-tunnel.ps1):
///   flutter run --dart-define=API_BASE_URL=http://localhost:4000
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'https://ops-backend-eqqd.onrender.com';
  }

  static String get apiRoot => '$baseUrl/api';
}
