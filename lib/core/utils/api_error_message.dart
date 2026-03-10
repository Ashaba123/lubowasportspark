import 'package:dio/dio.dart';

/// Thrown when the device has no network (e.g. wifi/mobile off). Used for proactive offline message.
class NoConnectivityException implements Exception {}

/// Returns a short, user-friendly message for API/network errors.
/// Use instead of error.toString() so users don't see raw DioException/SocketException.
String userFriendlyApiErrorMessage(Object? error) {
  if (error == null) return 'Something went wrong. Please try again.';
  if (error is NoConnectivityException) return 'No internet connection.';
  final msg = error.toString().toLowerCase();
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Cannot reach the server. Check your internet connection and try again.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final body = error.response?.data;
        final serverMessage = _serverMessage(body);
        if (status == 401 || status == 403) {
          return 'Wrong username or password.';
        }
        if (status == 400 && serverMessage != null) return serverMessage;
        if (status == 409 && serverMessage != null) return serverMessage;
        if (status != null && status >= 400 && status < 500 && serverMessage != null) {
          return serverMessage;
        }
        return 'Server error. Please try again later.';
      default:
        break;
    }
  }
  if (msg.contains('host lookup') || msg.contains('socketexception') || msg.contains('network')) {
    return 'Cannot reach the server. Check your internet connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

String? _serverMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final err = data['error'];
    if (err is Map<String, dynamic>) {
      final m = err['message'];
      if (m is String && m.trim().isNotEmpty) return m.trim();
    }
    final m = data['message'];
    if (m is String && m.trim().isNotEmpty) return m.trim();
  }
  return null;
}
