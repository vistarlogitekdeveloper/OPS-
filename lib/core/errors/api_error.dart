import 'package:dio/dio.dart';

/// Maps a [DioException] to a short user-facing message. Pulls the server's
/// `error.message` when present, otherwise falls back to status- or transport-
/// level hints.
class ApiError {
  ApiError({required this.status, required this.message, this.code});

  final int? status;
  final String message;
  final String? code;

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
