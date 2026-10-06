import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:vistar_event_tracker/vistar_event_tracker.dart'
    show EventType, TrackerConfig, VistarEventTracker, VistarEvents;

/// Usage analytics for the OPS (Operational Excellence) app, sent to the
/// in-house event tracker and read in the Platform Console under Analytics >
/// Event tracker.
///
/// Off unless the build is given both:
///   --dart-define=ET_APP_ID=ops_app --dart-define=ET_WRITE_KEY=wk_...
/// (register the app in the Platform Console, Settings > Event tracker; the
/// write key only lets a client append events, so it may ship in the app).
/// Optional --dart-define=ET_BASE_URL=... sends a test build's events
/// somewhere other than the API host the app uses (by default, the host of
/// the backend the app starts on, so a UAT build reports to UAT).
///
/// What is sent:
///   * screen views, by route pattern (ids replaced: `/review/:id`,
///     `/sites/:id`)
///   * sign-in / sign-out; the user as `ops:<user id>`, with their role as a
///     trait (OPS users belong to no organisation, so there is no org trait)
///   * named actions from successful API writes (see [_actions]):
///     `report_uploaded`, `submission_filed`, `submission_reviewed`, ...
///   * failed API calls (5xx or no connection), and client errors by TYPE
///     only (never the message, which can quote a server reply)
/// Never sent: request or response bodies, names, usernames, emails, phone
/// numbers, site / project names or codes, file names, marks, remarks or
/// comments, months, or any other record content.
///
/// NEVER IN THE WAY OF WORK. Nothing here is awaited by a screen, an upload, a
/// sign-in or a sign-out; start-up waits at most [_initBudget]; every call
/// swallows its own failures; the queue is capped at [_maxQueue] events
/// (oldest dropped) and lives in shared preferences; sending is in the
/// background with the SDK's backoff.
abstract final class Telemetry {
  static const _appId = String.fromEnvironment('ET_APP_ID');
  static const _writeKey = String.fromEnvironment('ET_WRITE_KEY');
  static const _baseUrlOverride = String.fromEnvironment('ET_BASE_URL');
  static const _appVersion = String.fromEnvironment('APP_VERSION');
  static const _initBudget = Duration(seconds: 2);
  static const _maxQueue = 200;

  static bool get enabled => _appId != '' && _writeKey != '';

  static VistarEventTracker get _t => VistarEventTracker.instance;
  static bool get _on => enabled && _t.isInitialized;

  static String? _lastScreen;
  static Future<void>? _resetting;

  /// Where events go: the origin (scheme + host) of [apiBaseUrl], unless
  /// ET_BASE_URL says otherwise.
  static String _origin(String apiBaseUrl) {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    final u = Uri.parse(apiBaseUrl);
    return '${u.scheme}://${u.authority}';
  }

  /// [apiBaseUrl] is the backend the app starts on (the user's saved choice
  /// or the build default; see BackendUrlController.load).
  static Future<void> init({required String apiBaseUrl}) async {
    if (!enabled) return;
    try {
      await _t
          .init(TrackerConfig(
            appId: _appId,
            writeKey: _writeKey,
            baseUrl: _origin(apiBaseUrl),
            appVersion: _appVersion.isEmpty ? null : _appVersion,
            maxQueueSize: _maxQueue,
            // The SDK's own error capture sends the exception message and
            // stack, and a message here can quote a server reply (a site
            // name, a remark). [_captureErrors] sends the type only.
            autoCaptureErrors: false,
          ))
          .timeout(_initBudget);
      _captureErrors();
    } catch (_) {
      // Analytics must never stop the app from starting.
    }
  }

  /// Client errors, by type only. Chains to whatever handled them before, so
  /// the app's own error handling is unchanged.
  static void _captureErrors() {
    if (!_on) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _clientError(details.exception, fatal: false, library: details.library);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _clientError(error, fatal: true);
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  /// An error that escaped to the app's guarded zone (main.dart), by type
  /// only.
  static void zoneError(Object e) {
    if (_on) _clientError(e, fatal: false, library: 'zone');
  }

  static void _clientError(Object e, {required bool fatal, String? library}) {
    try {
      error(VistarEvents.clientError, {
        'error': e.runtimeType.toString(),
        'library': ?library,
        'fatal': fatal,
      });
    } catch (_) {}
  }

  /// A screen, by its route pattern. Repeats are dropped.
  static void screen(String location) {
    if (!_on) return;
    final name = routePattern(location);
    if (name == _lastScreen) return;
    _lastScreen = name;
    _guard(() => _t.screen(name));
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_on) _guard(() => _t.track(name, properties: properties));
  }

  static void error(String name, Map<String, dynamic> properties) {
    if (_on) _guard(() => _t.track(name, properties: properties, type: EventType.error));
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // Analytics never surfaces as an app error.
    }
  }

  /// Fire and forget: the sign-in never waits for analytics.
  ///
  /// Called just BEFORE the auth state changes. With no sign-out in flight the
  /// SDK sets the user synchronously (before its first await), so the screen
  /// the sign-in leads to is already attributed to them.
  static void signedIn({required String userId, String? role}) {
    if (!_on || userId.isEmpty) return;
    final id = 'ops:$userId';
    final traits = <String, dynamic>{
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final pending = _resetting;
    if (pending == null) {
      _identify(id, traits);
      return;
    }
    // A sign-out just before (a shared machine changing hands) resets the
    // identity; let it finish so this one is not wiped by it.
    unawaited(() async {
      try {
        await pending.timeout(const Duration(seconds: 5), onTimeout: () {});
      } catch (_) {}
      _identify(id, traits);
    }());
  }

  static void _identify(String id, Map<String, dynamic> traits) {
    try {
      unawaited(_t.identify(id, traits: traits).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Fire and forget: the sign-out never waits for analytics (the SDK's reset
  /// sends what is queued first, which can take a while on a poor network).
  static void signedOut() {
    if (!_on) return;
    _lastScreen = null;
    try {
      late final Future<void> done;
      done = _t.reset().catchError((Object _) {}).whenComplete(() {
        if (identical(_resetting, done)) _resetting = null;
      });
      _resetting = done;
    } catch (_) {}
  }

  /// `/review/cm1x9z8k70000abcdxyz12345?x=1` -> `/review/:id`.
  ///
  /// Records are keyed by cuids (`c` + 24 lower-case letters and digits), so a
  /// segment of that shape, any long run of letters and digits, a number or a
  /// UUID becomes `:id`; anything else with a digit in it (a month such as
  /// `2026-09`, a site code) becomes `:ref`. The query string is dropped. An
  /// API version segment (`v1`) is kept.
  static String routePattern(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    return path.split('/').map((s) {
      if (s.isEmpty) return s;
      if (RegExp(r'^\d+$').hasMatch(s)) return ':id';
      if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-', caseSensitive: false).hasMatch(s)) return ':id';
      if (RegExp(r'^c[0-9a-z]{20,}$').hasMatch(s)) return ':id';
      if (RegExp(r'^[0-9A-Za-z_]{16,}$').hasMatch(s)) return ':id';
      if (RegExp(r'^v\d{1,2}$').hasMatch(s)) return s;
      if (RegExp(r'\d').hasMatch(s)) return ':ref';
      return s;
    }).join('/');
  }

  /// Successful API writes worth naming, by method and path (ids stripped;
  /// paths are relative to the API root `.../api/v1/ops-backend/api`). First
  /// match wins; anything else (reads, exports, sign-in, token refresh,
  /// unknown paths) is not reported.
  static final List<(String, RegExp, String)> _actions = [
    // The monthly cycle: a manager uploads a report per category and files
    // the cycle, the cluster manager approves or rejects it, Ops Excellence
    // scores each item.
    ('POST', RegExp(r'^/submissions/upload$'), 'report_uploaded'),
    ('POST', RegExp(r'^/submissions/:(id|ref)/submit$'), 'submission_filed'),
    ('POST', RegExp(r'^/submissions/:(id|ref)/decision$'), 'submission_reviewed'),
    ('POST', RegExp(r'^/submissions/:(id|ref)/items/:(id|ref)/score$'), 'item_scored'),
    // Admin: sites (projects), report categories, users.
    ('POST', RegExp(r'^/projects$'), 'project_created'),
    ('PATCH', RegExp(r'^/projects/:(id|ref)$'), 'project_updated'),
    ('DELETE', RegExp(r'^/projects/:(id|ref)$'), 'project_deactivated'),
    ('POST', RegExp(r'^/categories$'), 'category_created'),
    ('PATCH', RegExp(r'^/categories/:(id|ref)$'), 'category_updated'),
    ('DELETE', RegExp(r'^/categories/:(id|ref)$'), 'category_deactivated'),
    ('POST', RegExp(r'^/users$'), 'user_created'),
    ('PATCH', RegExp(r'^/users/:(id|ref)$'), 'user_updated'),
    ('DELETE', RegExp(r'^/users/:(id|ref)$'), 'user_deactivated'),
    ('POST', RegExp(r'^/users/:(id|ref)/password$'), 'user_password_set'),
    // Account
    ('POST', RegExp(r'^/auth/forgot-password$'), 'password_reset_requested'),
  ];

  /// The business event for a successful API call, or null.
  static String? actionFor(String method, String path) {
    final pattern = routePattern(path);
    for (final (m, re, name) in _actions) {
      if (m == method.toUpperCase() && re.hasMatch(pattern)) return name;
    }
    return null;
  }
}

/// Reports named actions and failed calls from the app's two Dio clients
/// (core/network/api_client.dart). Adds no headers and changes nothing about
/// the request or its handling.
class TelemetryInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // Both clients keep Dio's default validateStatus (the per-call overrides
    // only widen it within 2xx), so only a 2xx arrives here; the test is belt
    // and braces. Only a 2xx is an action that happened.
    final code = response.statusCode ?? 0;
    if (Telemetry.enabled && code >= 200 && code < 300) {
      String? name;
      try {
        final o = response.requestOptions;
        name = Telemetry.actionFor(o.method, o.path);
      } catch (_) {}
      if (name != null) Telemetry.track(name);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Telemetry.enabled) {
      try {
        final status = err.response?.statusCode;
        // A 4xx is a decision the server made (validation, a permission, an
        // expired token the auth interceptor refreshes), and a cancel is the
        // app's own.
        if ((status == null || status >= 500) && err.type != DioExceptionType.cancel) {
          Telemetry.error('api_error', {
            'endpoint': Telemetry.routePattern(err.requestOptions.path),
            'method': err.requestOptions.method,
            'status': ?status,
            'kind': err.type.name,
          });
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
