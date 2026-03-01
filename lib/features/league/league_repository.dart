import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import 'models/league.dart';

/// League API: public (by code) and authenticated (manage). Uses [ApiClient] for base URL and optional JWT.
class LeagueRepository {
  LeagueRepository({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  // —— Public (no auth) ——

  /// GET /lubowa/v1/public/leagues/<code>
  Future<PublicLeagueResponse> getPublicLeague(String code) async {
    final path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}';
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PublicLeagueResponse.fromJson(data);
  }

  /// GET /lubowa/v1/public/leagues/<code>/results?date=YYYY-MM-DD
  Future<PublicResultsResponse> getPublicResults(String code, {String? date}) async {
    final path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}/results';
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: date != null ? {'date': date} : null,
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PublicResultsResponse.fromJson(data);
  }

  // —— Auth (JWT) ——

  /// GET /lubowa/v1/me/league_roles
  Future<LeagueRoles> getMyLeagueRoles() async {
    final response = await _dio.get<Map<String, dynamic>>(AppConstants.pathLubowaMeRoles);
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return LeagueRoles.fromJson(data);
  }

  /// GET /lubowa/v1/me/player (404 if no player linked)
  Future<MePlayer?> getMyPlayer() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(AppConstants.pathLubowaMePlayer);
      final data = response.data;
      if (data == null) return null;
      return MePlayer.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /lubowa/v1/leagues
  Future<List<LeagueModel>> getLeagues() async {
    final response = await _dio.get<List<dynamic>>(AppConstants.pathLubowaLeagues);
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => LeagueModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /lubowa/v1/leagues
  Future<LeagueModel> createLeague({required String name, int legs = 1, int? bookingId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathLubowaLeagues,
      data: {
        'name': name,
        'legs': legs,
        if (bookingId != null) 'booking_id': bookingId,
      },
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return LeagueModel.fromJson(data);
  }

  /// GET leagues/[id]/teams
  Future<List<TeamModel>> getTeams(int leagueId) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/teams';
    final response = await _dio.get<List<dynamic>>(path);
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST leagues/[id]/teams
  Future<TeamModel> addTeam(int leagueId, {required String name, int? leaderUserId}) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/teams';
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'name': name, if (leaderUserId != null) 'leader_user_id': leaderUserId},
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return TeamModel.fromJson(data);
  }

  /// GET teams/[id]/players
  Future<List<PlayerModel>> getTeamPlayers(int teamId) async {
    final path = '/lubowa/v1/teams/$teamId/players';
    final response = await _dio.get<List<dynamic>>(path);
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => PlayerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST teams/[id]/players
  Future<PlayerModel> addPlayer(int teamId, {required String name, int goals = 0, int? userId}) async {
    final path = '/lubowa/v1/teams/$teamId/players';
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'name': name, 'goals': goals, if (userId != null) 'user_id': userId},
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PlayerModel.fromJson(data);
  }

  /// PATCH players/[id]
  Future<PlayerModel> updatePlayer(int playerId, {String? name, int? goals, int? userId}) async {
    final path = '/lubowa/v1/players/$playerId';
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (goals != null) body['goals'] = goals;
    if (userId != null) body['user_id'] = userId;
    final response = await _dio.patch<Map<String, dynamic>>(path, data: body);
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PlayerModel.fromJson(data);
  }

  /// DELETE players/[id]
  Future<void> deletePlayer(int playerId) async {
    await _dio.delete('/lubowa/v1/players/$playerId');
  }

  /// POST leagues/[id]/fixtures/generate
  Future<List<FixtureModel>> generateFixtures(int leagueId) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/fixtures/generate';
    final response = await _dio.post<List<dynamic>>(path);
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => FixtureModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET leagues/[id]/fixtures
  Future<List<FixtureModel>> getFixtures(int leagueId) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/fixtures';
    final response = await _dio.get<List<dynamic>>(path);
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => FixtureModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PATCH fixtures/[id]
  Future<FixtureModel> updateFixture(
    int fixtureId, {
    int? homeGoals,
    int? awayGoals,
    int? resultConfirmed,
    String? matchDate,
    String? matchTime,
    bool? startedAt,
  }) async {
    final path = '/lubowa/v1/fixtures/$fixtureId';
    final body = <String, dynamic>{};
    if (homeGoals != null) body['home_goals'] = homeGoals;
    if (awayGoals != null) body['away_goals'] = awayGoals;
    if (resultConfirmed != null) body['result_confirmed'] = resultConfirmed;
    if (matchDate != null) body['match_date'] = matchDate;
    if (matchTime != null) body['match_time'] = matchTime;
    if (startedAt != null) body['started_at'] = startedAt;
    final response = await _dio.patch<Map<String, dynamic>>(path, data: body);
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return FixtureModel.fromJson(data);
  }

  /// POST fixtures/[id]/goals
  Future<void> recordGoals(int fixtureId, {required int playerId, required int goals}) async {
    await _dio.post('/lubowa/v1/fixtures/$fixtureId/goals', data: {'player_id': playerId, 'goals': goals});
  }

  /// POST leagues/[id]/fixtures/reset
  Future<void> resetFixtures(int leagueId) async {
    await _dio.post('${AppConstants.pathLubowaLeagues}/$leagueId/fixtures/reset');
  }
}
