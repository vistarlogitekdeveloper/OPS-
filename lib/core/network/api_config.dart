/// Backend base URL.
///
/// The OpsApp backend is mounted inside the Vistar CRM under
/// `/api/v1/ops-backend`, and OpsApp adds its own `/api` segment inside.
/// So the value here is the host + CRM mount prefix WITHOUT a trailing
/// `/api` — `apiRoot` appends it.
///
/// Resolution order:
///   1. `--dart-define=API_BASE_URL=...` (highest precedence — for deployed
///      builds + Render env-var injection).
///   2. Default — local CRM running on port 3000.
///
/// Examples:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1/ops-backend
///   flutter build apk --dart-define=API_BASE_URL=https://DEPLOYED-CRM-HOST/api/v1/ops-backend
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'https://vistar-crm.onrender.com/api/v1/ops-backend';
  }

  static String get apiRoot => '$baseUrl/api';
}
