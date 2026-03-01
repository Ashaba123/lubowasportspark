import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';

/// JWT login: POST /jwt-auth/v1/token. Returns token string.
class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  /// POST /jwt-auth/v1/token. Returns JWT string. Throws on invalid credentials.
  Future<String> login(String username, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathJwtToken,
      data: {'username': username, 'password': password},
    );
    final data = response.data;
    final token = data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw DioException(requestOptions: response.requestOptions, message: 'No token in response');
    }
    return token;
  }
}
