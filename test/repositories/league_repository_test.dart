import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;
  late LeagueRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    repository = LeagueRepository(apiClient: createTestApiClient(dio: mockDio));
  });

  group('LeagueRepository (public)', () {
    test('getPublicLeague calls GET /lubowa/v1/public/leagues/{code}', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'league': {'id': 1, 'name': 'Test', 'code': 'ABC'},
          'standings': [],
          'fixtures': [],
          'top_scorers': [],
        }),
      );

      await repository.getPublicLeague('ABC123');

      verify(() => mockDio.get<Map<String, dynamic>>(
            '${AppConstants.pathLubowaPublicLeague}/ABC123',
          )).called(1);
    });

    test('getPublicResults calls GET .../results with optional date', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'league': {'id': 1, 'name': 'L', 'code': 'X'},
          'date': '2025-03-01',
          'results': [],
        }),
      );

      await repository.getPublicResults('X', date: '2025-03-01');

      verify(() => mockDio.get<Map<String, dynamic>>(
            '${AppConstants.pathLubowaPublicLeague}/X/results',
            queryParameters: {'date': '2025-03-01'},
          )).called(1);
    });
  });

  group('LeagueRepository (auth)', () {
    test('getMyLeagueRoles calls GET /lubowa/v1/me/league_roles', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'can_create_league': true,
          'managed_league_ids': [],
          'led_team_ids': [],
        }),
      );

      await repository.getMyLeagueRoles();

      verify(() => mockDio.get<Map<String, dynamic>>(AppConstants.pathLubowaMeRoles)).called(1);
    });

    test('getLeagues calls GET /lubowa/v1/leagues', () async {
      when(() => mockDio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => responseOk<List<dynamic>>([]),
      );

      await repository.getLeagues();

      verify(() => mockDio.get<List<dynamic>>(AppConstants.pathLubowaLeagues)).called(1);
    });

    test('createLeague calls POST /lubowa/v1/leagues with name and legs', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 1,
          'name': 'New League',
          'code': 'XYZ',
          'legs': 2,
          'created_by': 1,
          'created_at': '2025-03-01',
        }),
      );

      await repository.createLeague(name: 'New League', legs: 2);

      verify(() => mockDio.post<Map<String, dynamic>>(
            AppConstants.pathLubowaLeagues,
            data: {'name': 'New League', 'legs': 2},
          )).called(1);
    });
  });
}
