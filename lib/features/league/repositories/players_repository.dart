part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension PlayersRepository on LeagueRepository {
  /// GET teams/[id]/players (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after adding a player).
  Future<List<PlayerModel>> getTeamPlayers(int teamId, {bool forceRefresh = false}) async {
    const String basePath = '/lubowa/v1/teams';
    final String path = '$basePath/$teamId/players';
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
    return list.map((dynamic e) => PlayerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST teams/[id]/players
  Future<PlayerModel> addPlayer(int teamId, {required String name, int goals = 0, int? userId}) async {
    final String path = '/lubowa/v1/teams/$teamId/players';
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      path,
      data: <String, dynamic>{'name': name, 'goals': goals, if (userId != null) 'user_id': userId},
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return PlayerModel.fromJson(data);
  }

  /// PATCH players/[id]
  Future<PlayerModel> updatePlayer(int playerId, {String? name, int? goals, int? userId}) async {
    final String path = '/lubowa/v1/players/$playerId';
    final Map<String, dynamic> body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (goals != null) body['goals'] = goals;
    if (userId != null) body['user_id'] = userId;
    final Response<Map<String, dynamic>> response =
        await _dio.patch<Map<String, dynamic>>(path, data: body);
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return PlayerModel.fromJson(data);
  }

  /// DELETE players/[id]
  Future<void> deletePlayer(int playerId) async {
    await _dio.delete('/lubowa/v1/players/$playerId');
  }
}

