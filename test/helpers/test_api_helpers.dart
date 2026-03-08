import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';

/// Mock Dio for repository and widget tests. Stub [get]/[post]/[patch]/[delete] with [when].
class MockDio extends Mock implements Dio {}

/// Creates [ApiClient] that uses [dio] (e.g. [MockDio]) so tests can stub responses.
ApiClient createTestApiClient({Dio? dio}) {
  return ApiClient(
    baseUrl: AppConstants.defaultApiBaseUrl,
    dio: dio ?? MockDio(),
  );
}

/// [TokenStorage] for tests. In-memory.
class TestTokenStorage implements TokenStorage {
  String? _token;

  @override
  String? get currentToken => _token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> setToken(String? value) async {
    _token = value;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

/// Wraps [child] with [MaterialApp] and [MultiProvider] using [apiClient] and [tokenStorage].
/// Use as the root in tests: pumpWidget(wrapWithAppProviders(...)).
Widget wrapWithAppProviders({
  required Widget child,
  required ApiClient apiClient,
  TokenStorage? tokenStorage,
}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<TokenStorage>.value(value: tokenStorage ?? TestTokenStorage()),
      ],
      child: child,
    ),
  );
}

/// Builds a minimal [Response] for stubbing Dio.
Response<T> responseOk<T>(T data, {String path = '/'}) {
  return Response<T>(
    data: data,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );
}

Response<Map<String, dynamic>> response201(Map<String, dynamic> data, {String path = '/'}) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: 201,
    requestOptions: RequestOptions(path: path),
  );
}
