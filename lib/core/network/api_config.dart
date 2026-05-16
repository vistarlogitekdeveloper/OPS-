import 'package:flutter/foundation.dart';

/// Backend base URL.
///
/// Resolution order:
///   1. `--dart-define=API_BASE_URL=...` (highest precedence — set this for
///      prod, for physical devices, and when using a Cloudflare tunnel).
///   2. Platform default — Android emulator gets `10.0.2.2`, everything else
///      gets `localhost`. These only work for emulator/web/desktop; physical
///      phones cannot reach the host this way.
///
/// For a physical phone with no LAN dependency, run the backend's
/// `tools/dev-tunnel.ps1` script to start a Cloudflare quick tunnel, then run:
///   flutter run --dart-define=API_BASE_URL=<https://...trycloudflare.com>
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }
    return 'https://ops-backend-eqqd.onrender.com';
  }

  static String get apiRoot => '$baseUrl/api';
}
