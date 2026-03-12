part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension TeamsRepository on LeagueRepository {
  /// GET leagues/[id]/teams (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after adding a team).
  Future<List<TeamModel>> getTeams(int leagueId, {bool forceRefresh = false}) async {
    final String path = '${AppConstants.pathLubowaLeagues}/$leagueId/teams';
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        path,
        options: Options(extra: <String, Object>{'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(path);
    }
    final List<dynamic> list = LeagueRepository.listFromPaginated(response.data);
    return list.map((dynamic e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST leagues/[id]/teams
  Future<TeamModel> addTeam(int leagueId, {required String name, int? leaderUserId}) async {
    final String path = '${AppConstants.pathLubowaLeagues}/$leagueId/teams';
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      path,
      data: <String, dynamic>{'name': name, if (leaderUserId != null) 'leader_user_id': leaderUserId},
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return TeamModel.fromJson(data);
  }

  /// PATCH teams/[id]
  Future<TeamModel> updateTeam(
    int teamId, {
    String? name,
    int? leaderUserId,
  }) async {
    final Response<Map<String, dynamic>> response = await _dio.patch<Map<String, dynamic>>(
      '/lubowa/v1/teams/$teamId',
      data: <String, dynamic>{
        if (name != null) 'name': name,
        if (leaderUserId != null) 'leader_user_id': leaderUserId,
      },
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return TeamModel.fromJson(data);
  }

  /// DELETE teams/[id]
  Future<void> deleteTeam(int teamId) async {
    await _dio.delete('/lubowa/v1/teams/$teamId');
  }
}

