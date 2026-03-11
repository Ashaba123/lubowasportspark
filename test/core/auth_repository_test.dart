import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/auth/auth_repository.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';

import '../helpers/test_api_helpers.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mockDio;
  late AuthRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = _MockDio();
    repository = AuthRepository(
      apiClient: createTestApiClient(dio: mockDio),
    );
  });

  test('signup calls POST /lubowa/v1/signup and parses AuthResult', () async {
    when(
      () => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({
        'token': 'jwt-token',
        'user': {
          'id': 1,
          'name': 'Test User',
          'email': 'test@example.com',
          'username': 'testuser',
        },
      }),
    );

    final result = await repository.signup(
      email: 'test@example.com',
      password: 'password123',
      name: 'Test User',
    );

    expect(result.token, 'jwt-token');
    expect(result.user.id, 1);

    verify(
      () => mockDio.post<Map<String, dynamic>>(
        AppConstants.pathLubowaSignup,
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test('loginWithGoogle calls POST /lubowa/v1/google_login and parses AuthResult', () async {
    when(
      () => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({
        'token': 'jwt-google',
        'user': {
          'id': 2,
          'name': 'Google User',
          'email': 'google@example.com',
          'username': 'googleuser',
        },
      }),
    );

    final result = await repository.loginWithGoogle('id-token', displayName: 'Google User');

    expect(result.token, 'jwt-google');
    expect(result.user.id, 2);

    verify(
      () => mockDio.post<Map<String, dynamic>>(
        AppConstants.pathLubowaGoogleLogin,
        data: any(named: 'data'),
      ),
    ).called(1);
  });
}

