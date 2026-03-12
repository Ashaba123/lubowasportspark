part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension LeagueRolesRepository on LeagueRepository {
  /// GET /lubowa/v1/me/league_roles
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<LeagueRoles> getMyLeagueRoles({bool forceRefresh = false}) async {
    final Response<Map<String, dynamic>> response = await _dio.get<Map<String, dynamic>>(
      AppConstants.pathLubowaMeRoles,
      options: forceRefresh ? Options(extra: <String, Object>{'dio_cache_force_refresh': true}) : null,
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return LeagueRoles.fromJson(data);
  }

  /// GET /lubowa/v1/me/player (404 if no player linked)
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<MePlayer?> getMyPlayer({bool forceRefresh = false}) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio.get<Map<String, dynamic>>(
        AppConstants.pathLubowaMePlayer,
        options: forceRefresh ? Options(extra: <String, Object>{'dio_cache_force_refresh': true}) : null,
      );
      final Map<String, dynamic>? data = response.data;
      if (data == null) return null;
      return MePlayer.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

