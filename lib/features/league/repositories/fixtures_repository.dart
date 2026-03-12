part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension FixturesRepository on LeagueRepository {
  /// POST leagues/[id]/fixtures/generate
  Future<List<FixtureModel>> generateFixtures(int leagueId) async {
    final String path =
        '${AppConstants.pathLubowaLeagues}/$leagueId/fixtures/generate';
    final Response<List<dynamic>> response =
        await _dio.post<List<dynamic>>(path);
    final List<dynamic>? list = response.data;
    if (list == null) return <FixtureModel>[];
    return list
        .map((dynamic e) => FixtureModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET leagues/[id]/fixtures
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after generating fixtures).
  Future<List<FixtureModel>> getFixtures(int leagueId,
      {bool forceRefresh = false}) async {
    final String path = '${AppConstants.pathLubowaLeagues}/$leagueId/fixtures';
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        path,
        options:
            Options(extra: <String, Object>{'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(path);
    }
    final List<dynamic> list =
        LeagueRepository.listFromPaginated(response.data);
    return list
        .map((dynamic e) => FixtureModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final String path = '/lubowa/v1/fixtures/$fixtureId';
    final Map<String, dynamic> body = <String, dynamic>{};
    if (homeGoals != null) body['home_goals'] = homeGoals;
    if (awayGoals != null) body['away_goals'] = awayGoals;
    if (resultConfirmed != null) body['result_confirmed'] = resultConfirmed;
    if (matchDate != null) body['match_date'] = matchDate;
    if (matchTime != null) body['match_time'] = matchTime;
    if (startedAt != null) body['started_at'] = startedAt;
    final Response<Map<String, dynamic>> response =
        await _dio.patch<Map<String, dynamic>>(path, data: body);
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(
          requestOptions: response.requestOptions, message: 'Empty response');
    }
    return FixtureModel.fromJson(data);
  }

  /// POST fixtures/[id]/goals — returns created goal log entry + updated player in response.
  Future<GoalLogEntry> recordGoals(int fixtureId,
      {required int playerId, required int goals}) async {
    final Response<Map<String, dynamic>> response =
        await _dio.post<Map<String, dynamic>>(
      '/lubowa/v1/fixtures/$fixtureId/goals',
      data: <String, dynamic>{'player_id': playerId, 'goals': goals},
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(
          requestOptions: response.requestOptions, message: 'Empty response');
    }
    final Map<String, dynamic>? goalJson =
        data['goal'] as Map<String, dynamic>?;
    if (goalJson == null) {
      throw DioException(
          requestOptions: response.requestOptions,
          message: 'Missing goal in response');
    }
    return GoalLogEntry.fromJson(goalJson);
  }

  /// GET fixtures/[fixtureId]/goals (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after recording goals).
  Future<List<GoalLogEntry>> getFixtureGoals(int fixtureId,
      {bool forceRefresh = false}) async {
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        '/lubowa/v1/fixtures/$fixtureId/goals',
        options:
            Options(extra: <String, Object>{'dio_cache_force_refresh': true}),
      );
    } else {
      response =
          await _dio.get<dynamic>('/lubowa/v1/fixtures/$fixtureId/goals');
    }
    final List<dynamic> list =
        LeagueRepository.listFromPaginated(response.data);
    return list
        .map((dynamic e) => GoalLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GoalLogEntry> updateFixtureGoal({
    required int fixtureId,
    required int goalId,
    required int goals,
  }) async {
    final Response<Map<String, dynamic>> response =
        await _dio.patch<Map<String, dynamic>>(
      '/lubowa/v1/fixtures/$fixtureId/goals/$goalId',
      data: <String, dynamic>{'goals': goals},
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(
          requestOptions: response.requestOptions, message: 'Empty response');
    }
    return GoalLogEntry.fromJson(data);
  }

  /// DELETE fixtures/[fixtureId]/goals/[goalId]
  Future<void> deleteFixtureGoal(
      {required int fixtureId, required int goalId}) async {
    await _dio.delete('/lubowa/v1/fixtures/$fixtureId/goals/$goalId');
  }

  /// POST leagues/[id]/fixtures/reset
  Future<void> resetFixtures(int leagueId) async {
    await _dio
        .post('${AppConstants.pathLubowaLeagues}/$leagueId/fixtures/reset');
  }
}
