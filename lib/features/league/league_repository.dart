import 'dart:async';

import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

/// League API: public (by code) and authenticated (manage). Uses [ApiClient] for base URL and optional JWT.
class LeagueRepository {
  LeagueRepository({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  // —— Public (no auth) ——

  /// GET /lubowa/v1/public/leagues/<code>
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<PublicLeagueResponse> getPublicLeague(String code, {bool forceRefresh = false}) async {
    final path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}';
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PublicLeagueResponse.fromJson(data);
  }

  /// Stream polling wrapper around [getPublicLeague], emitting updates every [interval].
  Stream<PublicLeagueResponse> getPublicLeagueStream(
    String code, {
    Duration interval = const Duration(seconds: 3),
  }) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Stream<PublicLeagueResponse>.empty();
    }
    return _poll<PublicLeagueResponse>(
      () => getPublicLeague(trimmed, forceRefresh: true),
      interval,
    );
  }

  /// GET /lubowa/v1/public/leagues/<code>/results?date=YYYY-MM-DD
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<PublicResultsResponse> getPublicResults(String code, {String? date, bool forceRefresh = false}) async {
    final path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}/results';
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: date != null ? {'date': date} : null,
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return PublicResultsResponse.fromJson(data);
  }

  /// Stream polling wrapper around [getPublicResults], emitting updates every [interval].
  Stream<PublicResultsResponse> getPublicResultsStream(
    String code, {
    String? date,
    Duration interval = const Duration(seconds: 3),
  }) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Stream<PublicResultsResponse>.empty();
    }
    return _poll<PublicResultsResponse>(
      () => getPublicResults(trimmed, date: date, forceRefresh: true),
      interval,
    );
  }

  // —— Auth (JWT) ——

  /// GET /lubowa/v1/me/league_roles
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<LeagueRoles> getMyLeagueRoles({bool forceRefresh = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.pathLubowaMeRoles,
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return LeagueRoles.fromJson(data);
  }

  /// GET /lubowa/v1/me/player (404 if no player linked)
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<MePlayer?> getMyPlayer({bool forceRefresh = false}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AppConstants.pathLubowaMePlayer,
        options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
      );
      final data = response.data;
      if (data == null) return null;
      return MePlayer.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /lubowa/v1/leagues (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after creating a league).
  Future<List<LeagueModel>> getLeagues({bool forceRefresh = false}) async {
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        AppConstants.pathLubowaLeagues,
        options: Options(extra: {'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(AppConstants.pathLubowaLeagues);
    }
    final list = _listFromPaginated(response.data);
    return list.map((e) => LeagueModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll leagues every [interval] and emit updates as a stream.
  Stream<List<LeagueModel>> getLeaguesStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<LeagueModel>>(
      () => getLeagues(forceRefresh: true),
      interval,
    );
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

  /// GET leagues/[id]/teams (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after adding a team).
  Future<List<TeamModel>> getTeams(int leagueId, {bool forceRefresh = false}) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/teams';
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        path,
        options: Options(extra: {'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(path);
    }
    final list = _listFromPaginated(response.data);
    return list.map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll teams for [leagueId] every [interval] and emit updates as a stream.
  Stream<List<TeamModel>> getTeamsStream(
    int leagueId, {
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<TeamModel>>(
      () => getTeams(leagueId, forceRefresh: true),
      interval,
    );
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

  /// GET teams/[id]/players (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after adding a player).
  Future<List<PlayerModel>> getTeamPlayers(int teamId, {bool forceRefresh = false}) async {
    final path = '/lubowa/v1/teams/$teamId/players';
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        path,
        options: Options(extra: {'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(path);
    }
    final list = _listFromPaginated(response.data);
    return list.map((e) => PlayerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll players for [teamId] every [interval] and emit updates as a stream.
  Stream<List<PlayerModel>> getTeamPlayersStream(
    int teamId, {
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<PlayerModel>>(
      () => getTeamPlayers(teamId, forceRefresh: true),
      interval,
    );
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
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after generating fixtures).
  Future<List<FixtureModel>> getFixtures(int leagueId, {bool forceRefresh = false}) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId/fixtures';
    Response<List<dynamic>> response;
    if (forceRefresh) {
      response = await _dio.get<List<dynamic>>(path, options: Options(extra: {'dio_cache_force_refresh': true}));
    } else {
      response = await _dio.get<List<dynamic>>(path);
    }
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => FixtureModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll fixtures for [leagueId] every [interval] and emit updates as a stream.
  Stream<List<FixtureModel>> getFixturesStream(
    int leagueId, {
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<FixtureModel>>(
      () => getFixtures(leagueId, forceRefresh: true),
      interval,
    );
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

  /// POST fixtures/[id]/goals — returns created goal log entry + updated player in response.
  Future<GoalLogEntry> recordGoals(int fixtureId, {required int playerId, required int goals}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/lubowa/v1/fixtures/$fixtureId/goals',
      data: {'player_id': playerId, 'goals': goals},
    );
    final data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    final goalJson = data['goal'] as Map<String, dynamic>?;
    if (goalJson == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Missing goal in response');
    }
    return GoalLogEntry.fromJson(goalJson);
  }

  /// GET fixtures/[fixtureId]/goals (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after recording goals).
  Future<List<GoalLogEntry>> getFixtureGoals(int fixtureId, {bool forceRefresh = false}) async {
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        '/lubowa/v1/fixtures/$fixtureId/goals',
        options: Options(extra: {'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>('/lubowa/v1/fixtures/$fixtureId/goals');
    }
    final list = _listFromPaginated(response.data);
    return list.map((e) => GoalLogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll goals for [fixtureId] every [interval] and emit updates as a stream.
  Stream<List<GoalLogEntry>> getFixtureGoalsStream(
    int fixtureId, {
    Duration interval = const Duration(seconds: 3),
  }) {
    return _poll<List<GoalLogEntry>>(
      () => getFixtureGoals(fixtureId, forceRefresh: true),
      interval,
    );
  }

  /// PATCH fixtures/[fixtureId]/goals/[goalId] — update a single goal log entry.
  static List<dynamic> _listFromPaginated(dynamic raw) {
    if (raw == null) return [];
    if (raw is Map && raw.containsKey('data')) return raw['data'] as List<dynamic>? ?? [];
    if (raw is List) return raw;
    return [];
  }

  Future<GoalLogEntry> updateFixtureGoal({
    required int fixtureId,
    required int goalId,
    required int goals,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/lubowa/v1/fixtures/$fixtureId/goals/$goalId',
      data: {'goals': goals},
    );
    final data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return GoalLogEntry.fromJson(data);
  }

  /// DELETE fixtures/[fixtureId]/goals/[goalId]
  Future<void> deleteFixtureGoal({required int fixtureId, required int goalId}) async {
    await _dio.delete('/lubowa/v1/fixtures/$fixtureId/goals/$goalId');
  }

  /// POST leagues/[id]/fixtures/reset
  Future<void> resetFixtures(int leagueId) async {
    await _dio.post('${AppConstants.pathLubowaLeagues}/$leagueId/fixtures/reset');
  }

  /// PATCH leagues/[id]
  Future<LeagueModel> updateLeague(
    int leagueId, {
    String? name,
    int? legs,
  }) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId';
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (legs != null) body['legs'] = legs;
    final response = await _dio.patch<Map<String, dynamic>>(path, data: body);
    final data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return LeagueModel.fromJson(data);
  }

  /// DELETE leagues/[id]
  Future<void> deleteLeague(int leagueId) async {
    final path = '${AppConstants.pathLubowaLeagues}/$leagueId';
    await _dio.delete(path);
  }

  /// PATCH teams/[id]
  Future<TeamModel> updateTeam(
    int teamId, {
    String? name,
    int? leaderUserId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/lubowa/v1/teams/$teamId',
      data: {
        if (name != null) 'name': name,
        if (leaderUserId != null) 'leader_user_id': leaderUserId,
      },
    );
    final data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return TeamModel.fromJson(data);
  }

  /// DELETE teams/[id]
  Future<void> deleteTeam(int teamId) async {
    await _dio.delete('/lubowa/v1/teams/$teamId');
  }

  Stream<T> _poll<T>(Future<T> Function() fetch, Duration interval) {
    final controller = StreamController<T>();
    Timer? timer;

    Future<void> tick() async {
      try {
        final value = await fetch();
        if (!controller.isClosed) controller.add(value);
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    controller.onListen = () {
      tick();
      timer = Timer.periodic(interval, (_) => tick());
    };
    controller.onCancel = () {
      timer?.cancel();
      if (!controller.isClosed) {
        controller.close();
      }
    };

    return controller.stream;
  }
}
