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
