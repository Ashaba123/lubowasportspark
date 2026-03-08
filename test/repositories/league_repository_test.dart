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
      when(() => mockDio.get<dynamic>(any())).thenAnswer(
        (_) async => responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}}),
      );

      await repository.getLeagues();

      verify(() => mockDio.get<dynamic>(AppConstants.pathLubowaLeagues)).called(1);
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

    test('getTeams calls GET /lubowa/v1/leagues/{id}/teams', () async {
      when(() => mockDio.get<dynamic>(any())).thenAnswer(
        (_) async => responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}}),
      );

      await repository.getTeams(1);

      verify(() => mockDio.get<dynamic>(
            '${AppConstants.pathLubowaLeagues}/1/teams',
          )).called(1);
    });

    test('addTeam calls POST /lubowa/v1/leagues/{id}/teams', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 10,
          'name': 'Team A',
          'leader_user_id': null,
        }),
      );

      await repository.addTeam(1, name: 'Team A');

      verify(() => mockDio.post<Map<String, dynamic>>(
            '${AppConstants.pathLubowaLeagues}/1/teams',
            data: {'name': 'Team A'},
          )).called(1);
    });

    test('getTeamPlayers calls GET /lubowa/v1/teams/{id}/players', () async {
      when(() => mockDio.get<dynamic>(any())).thenAnswer(
        (_) async => responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}}),
      );

      await repository.getTeamPlayers(5);

      verify(() => mockDio.get<dynamic>(
            '/lubowa/v1/teams/5/players',
          )).called(1);
    });

    test('addPlayer calls POST /lubowa/v1/teams/{id}/players', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 20,
          'name': 'Player 1',
          'goals': 0,
          'user_id': null,
        }),
      );

      await repository.addPlayer(5, name: 'Player 1');

      verify(() => mockDio.post<Map<String, dynamic>>(
            '/lubowa/v1/teams/5/players',
            data: {'name': 'Player 1', 'goals': 0},
          )).called(1);
    });

    test('generateFixtures calls POST /lubowa/v1/leagues/{id}/fixtures/generate', () async {
      when(() => mockDio.post<List<dynamic>>(any())).thenAnswer(
        (_) async => responseOk<List<dynamic>>([]),
      );

      await repository.generateFixtures(1);

      verify(() => mockDio.post<List<dynamic>>(
            '${AppConstants.pathLubowaLeagues}/1/fixtures/generate',
          )).called(1);
    });

    test('getFixtures calls GET /lubowa/v1/leagues/{id}/fixtures', () async {
      when(() => mockDio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => responseOk<List<dynamic>>([]),
      );

      await repository.getFixtures(1);

      verify(() => mockDio.get<List<dynamic>>(
            '${AppConstants.pathLubowaLeagues}/1/fixtures',
          )).called(1);
    });

    test('updateFixture calls PATCH /lubowa/v1/fixtures/{id} with home_goals and away_goals', () async {
      when(() => mockDio.patch<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 1,
          'home_team_id': 10,
          'away_team_id': 11,
          'home_goals': 2,
          'away_goals': 1,
          'result_confirmed': 1,
        }),
      );

      await repository.updateFixture(1, homeGoals: 2, awayGoals: 1);

      verify(() => mockDio.patch<Map<String, dynamic>>(
            '/lubowa/v1/fixtures/1',
            data: {'home_goals': 2, 'away_goals': 1},
          )).called(1);
    });

    test('recordGoals calls POST /lubowa/v1/fixtures/{id}/goals with player_id and goals', () async {
      when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'goal': {
            'id': 1,
            'fixture_id': 5,
            'team_id': 10,
            'player_id': 20,
            'goals': 2,
            'created_at': '2025-03-01T12:00:00Z',
          },
        }),
      );

      await repository.recordGoals(5, playerId: 20, goals: 2);

      verify(() => mockDio.post<Map<String, dynamic>>(
            '/lubowa/v1/fixtures/5/goals',
            data: {'player_id': 20, 'goals': 2},
          )).called(1);
    });

    test('getFixtureGoals calls GET /lubowa/v1/fixtures/{id}/goals', () async {
      when(() => mockDio.get<dynamic>(any())).thenAnswer(
        (_) async => responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}}),
      );

      await repository.getFixtureGoals(5);

      verify(() => mockDio.get<dynamic>('/lubowa/v1/fixtures/5/goals')).called(1);
    });

    test('updateFixtureGoal calls PATCH /lubowa/v1/fixtures/{fid}/goals/{gid}', () async {
      when(() => mockDio.patch<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 1,
          'fixture_id': 5,
          'team_id': 10,
          'player_id': 20,
          'goals': 3,
          'created_at': '2025-03-01T12:00:00Z',
        }),
      );

      await repository.updateFixtureGoal(fixtureId: 5, goalId: 1, goals: 3);

      verify(() => mockDio.patch<Map<String, dynamic>>(
            '/lubowa/v1/fixtures/5/goals/1',
            data: {'goals': 3},
          )).called(1);
    });

    test('deleteFixtureGoal calls DELETE /lubowa/v1/fixtures/{fid}/goals/{gid}', () async {
      when(() => mockDio.delete<dynamic>(any())).thenAnswer((_) async => Response<void>(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
          ));

      await repository.deleteFixtureGoal(fixtureId: 5, goalId: 1);

      verify(() => mockDio.delete<dynamic>('/lubowa/v1/fixtures/5/goals/1')).called(1);
    });

    test('resetFixtures calls POST /lubowa/v1/leagues/{id}/fixtures/reset', () async {
      when(() => mockDio.post<dynamic>(any())).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        ),
      );

      await repository.resetFixtures(1);

      verify(() => mockDio.post<dynamic>(
            '${AppConstants.pathLubowaLeagues}/1/fixtures/reset',
          )).called(1);
    });

    test('updatePlayer calls PATCH /lubowa/v1/players/{id} with goals', () async {
      when(() => mockDio.patch<Map<String, dynamic>>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => responseOk<Map<String, dynamic>>({
          'id': 20,
          'name': 'Player 1',
          'goals': 5,
          'user_id': null,
        }),
      );

      await repository.updatePlayer(20, goals: 5);

      verify(() => mockDio.patch<Map<String, dynamic>>(
            '/lubowa/v1/players/20',
            data: {'goals': 5},
          )).called(1);
    });
  });
}
