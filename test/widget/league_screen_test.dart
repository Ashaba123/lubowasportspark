import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/league/league_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LeagueScreen shows Leagues app bar and manage section', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const LeagueScreen(),
      ),
    );

    expect(find.text('Leagues'), findsOneWidget);
    expect(find.text('Login to manage a league'), findsOneWidget);
    expect(find.text('Manage leagues'), findsOneWidget);
  });

  // Public league stats have moved to the Home screen; LeagueScreen now only
  // shows the manage section (login + Manage leagues button), so we no longer
  // test entering a code and tapping View here.

  testWidgets('LeagueScreen with token shows Manage leagues and opens manage screen', (WidgetTester tester) async {
    final tokenStorage = TestTokenStorage();
    await tokenStorage.setToken('test-token');

    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == AppConstants.pathLubowaMeRoles) {
        return responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [],
          'led_team_ids': [],
        });
      }
      if (path == AppConstants.pathLubowaMePlayer) {
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 404,
          data: null,
        );
      }
      return responseOk<Map<String, dynamic>>({});
    });

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: tokenStorage,
        child: const LeagueScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Manage leagues'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Manage leagues'), findsWidgets);
    expect(find.text('Manage your leagues'), findsOneWidget);
    expect(find.text('Create league'), findsOneWidget);
  });

  testWidgets('Create league dialog submits name and legs', (WidgetTester tester) async {
    final tokenStorage = TestTokenStorage();
    await tokenStorage.setToken('test-token');

    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == AppConstants.pathLubowaMeRoles) {
        return responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [],
          'led_team_ids': [],
        });
      }
      if (path == AppConstants.pathLubowaMePlayer) {
        return Response(requestOptions: RequestOptions(path: path), statusCode: 404, data: null);
      }
      return responseOk<Map<String, dynamic>>({});
    });
    when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({
        'id': 1,
        'name': 'My League',
        'code': 'ABC123',
        'legs': 1,
        'created_by': 1,
        'created_at': '2025-03-01',
      }),
    );

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: tokenStorage,
        child: const LeagueScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Manage leagues'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Create league'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'My League');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(() => mockDio.post<Map<String, dynamic>>(
          AppConstants.pathLubowaLeagues,
          data: {'name': 'My League', 'legs': 1},
        )).called(1);
  });

  testWidgets('Add team dialog submits team name', (WidgetTester tester) async {
    final tokenStorage = TestTokenStorage();
    await tokenStorage.setToken('test-token');

    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == AppConstants.pathLubowaMeRoles) {
        return responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [1],
          'led_team_ids': [],
        });
      }
      if (path == AppConstants.pathLubowaMePlayer) {
        return Response(requestOptions: RequestOptions(path: path), statusCode: 404, data: null);
      }
      return responseOk<Map<String, dynamic>>({});
    });
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == '${AppConstants.pathLubowaLeagues}/1/teams') {
        return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
      }
      if (path == '${AppConstants.pathLubowaLeagues}/1/fixtures') {
        return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
      }
      if (path == AppConstants.pathLubowaLeagues) {
        return responseOk<dynamic>({
          'data': [
            {'id': 1, 'name': 'Test League', 'code': 'X1', 'legs': 1, 'created_by': 1, 'created_at': '2025-03-01'},
          ],
          'meta': {'page': 1, 'per_page': 20, 'total': 1},
        });
      }
      return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
    });
    when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({'id': 10, 'name': 'Eagles', 'leader_user_id': null}),
    );

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: tokenStorage,
        child: const LeagueScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Manage leagues'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Leagues I manage'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Test League'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Add team'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Eagles');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(() => mockDio.post<Map<String, dynamic>>(
          '${AppConstants.pathLubowaLeagues}/1/teams',
          data: {'name': 'Eagles'},
        )).called(1);
  });

  testWidgets('View fixtures opens fixtures screen and Generate calls API', (WidgetTester tester) async {
    final tokenStorage = TestTokenStorage();
    await tokenStorage.setToken('test-token');

    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == AppConstants.pathLubowaMeRoles) {
        return responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [1],
          'led_team_ids': [],
        });
      }
      if (path == AppConstants.pathLubowaMePlayer) {
        return Response(requestOptions: RequestOptions(path: path), statusCode: 404, data: null);
      }
      return responseOk<Map<String, dynamic>>({});
    });
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == '${AppConstants.pathLubowaLeagues}/1/teams') {
        return responseOk<dynamic>({
          'data': [
            {'id': 10, 'name': 'Team A', 'leader_user_id': null},
            {'id': 11, 'name': 'Team B', 'leader_user_id': null},
          ],
          'meta': {'page': 1, 'per_page': 20, 'total': 2},
        });
      }
      if (path == '${AppConstants.pathLubowaLeagues}/1/fixtures') {
        return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
      }
      if (path == AppConstants.pathLubowaLeagues) {
        return responseOk<dynamic>({
          'data': [
            {'id': 1, 'name': 'Test League', 'code': 'X1', 'legs': 1, 'created_by': 1, 'created_at': '2025-03-01'},
          ],
          'meta': {'page': 1, 'per_page': 20, 'total': 1},
        });
      }
      return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
    });
    when(() => mockDio.get<List<dynamic>>(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => responseOk<List<dynamic>>([]),
    );
    when(() => mockDio.post<List<dynamic>>(any())).thenAnswer(
      (_) async => responseOk<List<dynamic>>([]),
    );

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: tokenStorage,
        child: const LeagueScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Manage leagues'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Leagues I manage'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Test League'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Fixtures are now managed from a dedicated fixtures screen only; the
    // league detail screen no longer shows a "View fixtures" button.
    expect(find.text('View fixtures'), findsNothing);
  });

  testWidgets('Add player dialog submits player name', (WidgetTester tester) async {
    final tokenStorage = TestTokenStorage();
    await tokenStorage.setToken('test-token');

    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == AppConstants.pathLubowaMeRoles) {
        return responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [1],
          'led_team_ids': [],
        });
      }
      if (path == AppConstants.pathLubowaMePlayer) {
        return Response(requestOptions: RequestOptions(path: path), statusCode: 404, data: null);
      }
      return responseOk<Map<String, dynamic>>({});
    });
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      if (path == '${AppConstants.pathLubowaLeagues}/1/teams') {
        return responseOk<dynamic>({
          'data': [
            {'id': 10, 'name': 'Eagles', 'leader_user_id': null},
          ],
          'meta': {'page': 1, 'per_page': 20, 'total': 1},
        });
      }
      if (path == '${AppConstants.pathLubowaLeagues}/1/fixtures') {
        return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
      }
      if (path == AppConstants.pathLubowaLeagues) {
        return responseOk<dynamic>({
          'data': [
            {'id': 1, 'name': 'Test League', 'code': 'X1', 'legs': 1, 'created_by': 1, 'created_at': '2025-03-01'},
          ],
          'meta': {'page': 1, 'per_page': 20, 'total': 1},
        });
      }
      if (path == '/lubowa/v1/teams/10/players') {
        return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
      }
      return responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}});
    });
    when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({'id': 20, 'name': 'Henry', 'goals': 0, 'user_id': null}),
    );

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: tokenStorage,
        child: const LeagueScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Manage leagues'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Leagues I manage'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Test League'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Eagles'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Henry');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(() => mockDio.post<Map<String, dynamic>>(
          '/lubowa/v1/teams/10/players',
          data: {'name': 'Henry', 'goals': 0},
        )).called(1);
  });
}
