import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/models/wp_user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final WpUser user;
}

/// Auth repository built on Dio + ApiClient.
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

  /// GET /wp/v2/users/me. Returns current WordPress user for the JWT.
  Future<WpUser> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.pathWpCurrentUser,
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty current user response',
      );
    }
    return WpUser.fromJson(data);
  }

  /// POST /lubowa/v1/signup. Returns JWT token and current user.
  Future<AuthResult> signup({
    required String email,
    required String password,
    String? name,
    String? username,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathLubowaSignup,
      data: <String, dynamic>{
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty signup response',
      );
    }
    final token = (data['token'] as String?) ?? '';
    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Missing user in signup response',
      );
    }
    return AuthResult(token: token, user: WpUser.fromJson(userJson));
  }

  /// POST /lubowa/v1/google_login. Returns JWT token and current user.
  Future<AuthResult> loginWithGoogle(String idToken, {String? displayName}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathLubowaGoogleLogin,
      data: <String, dynamic>{
        'id_token': idToken,
        if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
      },
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty Google login response',
      );
    }
    final token = (data['token'] as String?) ?? '';
    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Missing user in Google login response',
      );
    }
    return AuthResult(token: token, user: WpUser.fromJson(userJson));
  }
}
