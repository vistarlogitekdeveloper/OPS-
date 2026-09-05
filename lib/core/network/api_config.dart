/// Backend base URL.
///
/// The OpsApp backend is mounted inside the Vistar CRM under
/// `/api/v1/ops-backend`, and OpsApp adds its own `/api` segment inside.
/// So a base URL here is the host + CRM mount prefix WITHOUT a trailing
/// `/api` — [apiRootFor] appends it.
///
/// The CRM runs on more than one host, so the app ships knowing about all of
/// them and lets the user switch at runtime (see `backendUrlProvider`). One
/// build therefore works against every deployment; no rebuild needed to move
/// between them.
///
/// Resolution order for the *initial* value:
///   1. A backend the user picked previously (persisted; see BackendUrlController).
///   2. `--dart-define=API_BASE_URL=...` baked in at build time.
///   3. The first entry in [knownBackends].
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// A deployment the app can talk to.
  static const knownBackends = <BackendOption>[
    BackendOption(
      label: 'Production',
      host: 'api.vistarlogitek.com',
      url: 'https://api.vistarlogitek.com/api/v1/ops-backend',
    ),
    BackendOption(
      label: 'Render',
      host: 'https://api.vistarlogitek.com',
      url: 'https://https://api.vistarlogitek.com/api/v1/ops-backend',
    ),
  ];

  /// What this build defaults to before the user picks anything.
  static String get buildTimeBaseUrl =>
      _override.isNotEmpty ? normalize(_override) : knownBackends.first.url;

  /// Trailing slashes would produce `//api` once the suffix is appended.
  static String normalize(String raw) {
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// The URL Dio should use as its base, for a given backend.
  static String apiRootFor(String baseUrl) => '${normalize(baseUrl)}/api';

  /// The known backend matching [url], or null for a custom one.
  static BackendOption? optionFor(String url) {
    final n = normalize(url);
    for (final b in knownBackends) {
      if (b.url == n) return b;
    }
    return null;
  }

  /// Build-time default. Prefer watching `backendUrlProvider` for the value
  /// actually in use — this stays for callers that need it before startup.
  static String get baseUrl => buildTimeBaseUrl;

  static String get apiRoot => apiRootFor(buildTimeBaseUrl);
}

class BackendOption {
  const BackendOption({
    required this.label,
    required this.host,
    required this.url,
  });

  final String label;
  final String host;
  final String url;
}
