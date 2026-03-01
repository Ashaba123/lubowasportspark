import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Single HTTP client for WordPress REST API. Base URL from [baseUrl];
/// JWT sent via [AuthInterceptor]. On 401, [onUnauthorized] is invoked.
/// Pass [dio] in tests to use a mock/stub Dio.
class ApiClient {
  ApiClient({
    String? baseUrl,
    String? Function()? tokenGetter,
    void Function()? onUnauthorized,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl,
        _tokenGetter = tokenGetter,
        _onUnauthorized = onUnauthorized {
    if (dio != null) {
      _dio = dio;
    } else {
      _dio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ));
      _dio.interceptors.add(
        AuthInterceptor(
          tokenGetter: _tokenGetter,
          onUnauthorized: _onUnauthorized,
        ),
      );
    }
  }

  final String _baseUrl;
  final String? Function()? _tokenGetter;
  final void Function()? _onUnauthorized;
  late final Dio _dio;

  String get baseUrl => _baseUrl;

  Dio get dio => _dio;
}

/// Adds Bearer token to requests; on 401 calls [onUnauthorized].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({this.tokenGetter, this.onUnauthorized});

  final String? Function()? tokenGetter;
  final void Function()? onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenGetter?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
