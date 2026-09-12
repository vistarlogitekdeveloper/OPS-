import 'package:dio/dio.dart';

/// Maps a [DioException] to a short user-facing message. Pulls the server's
/// `error.message` when present, otherwise falls back to status- or transport-
/// level hints.
class ApiError {
  ApiError({required this.status, required this.message, this.code});

  final int? status;
  final String message;
  final String? code;

  /// Whether running the same request again could plausibly succeed.
  ///
  /// A 4xx is the server's settled answer — "you may not do this", "that file
  /// type isn't allowed", "this report is already filed" — and repeating the
  /// request returns the same thing, so offering a retry only invites the user
  /// to hit the same wall. Transport failures and 5xx are worth another go, as
  /// are the two status codes that explicitly mean "try again": 408 and 429.
  bool get isRetryable {
    final s = status;
    if (s == null) return true; // no response at all — network or timeout
    if (s == 408 || s == 429) return true;
    return s >= 500;
  }

  static ApiError from(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      String? message;
      String? code;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        message = err['message']?.toString();
        code = err['code']?.toString();
      }
      return ApiError(
        status: e.response?.statusCode,
        message: message ?? _fallbackMessage(e),
        code: code,
      );
    }
    return ApiError(status: null, message: e.toString());
  }

  static String _fallbackMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'Could not reach the server. Is the backend running?';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.badResponse:
        return 'Request failed (${e.response?.statusCode}).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error: ${e.message ?? e.type.name}';
    }
  }
}
