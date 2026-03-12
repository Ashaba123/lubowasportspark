part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension LeaguesRepository on LeagueRepository {
  /// GET /lubowa/v1/leagues (paginated: response has data + meta). Asks per_page 100 (API max).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after creating a league).
  Future<List<LeagueModel>> getLeagues({bool forceRefresh = false}) async {
    Response<dynamic> response;
    if (forceRefresh) {
      response = await _dio.get<dynamic>(
        AppConstants.pathLubowaLeagues,
        options: Options(extra: <String, Object>{'dio_cache_force_refresh': true}),
      );
    } else {
      response = await _dio.get<dynamic>(AppConstants.pathLubowaLeagues);
    }
    final List<dynamic> list = LeagueRepository.listFromPaginated(response.data);
    return list.map((dynamic e) => LeagueModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /lubowa/v1/leagues
  Future<LeagueModel> createLeague({required String name, int legs = 1, int? bookingId}) async {
    final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathLubowaLeagues,
      data: <String, dynamic>{
        'name': name,
        'legs': legs,
        if (bookingId != null) 'booking_id': bookingId,
      },
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return LeagueModel.fromJson(data);
  }

  /// PATCH leagues/[id]
  Future<LeagueModel> updateLeague(
    int leagueId, {
    String? name,
    int? legs,
  }) async {
    final String path = '${AppConstants.pathLubowaLeagues}/$leagueId';
    final Map<String, dynamic> body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (legs != null) body['legs'] = legs;
    final Response<Map<String, dynamic>> response =
        await _dio.patch<Map<String, dynamic>>(path, data: body);
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return LeagueModel.fromJson(data);
  }

  /// DELETE leagues/[id]
  Future<void> deleteLeague(int leagueId) async {
    final String path = '${AppConstants.pathLubowaLeagues}/$leagueId';
    await _dio.delete(path);
  }
}

