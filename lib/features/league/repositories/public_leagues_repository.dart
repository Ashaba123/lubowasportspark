part of 'package:lubowa_sports_park/features/league/league_repository.dart';

extension PublicLeaguesRepository on LeagueRepository {
  /// GET /lubowa/v1/public/leagues/<code>
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<PublicLeagueResponse> getPublicLeague(String code, {bool forceRefresh = false}) async {
    final String path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}';
    final Response<Map<String, dynamic>> response = await _dio.get<Map<String, dynamic>>(
      path,
      options: forceRefresh ? Options(extra: <String, Object>{'dio_cache_force_refresh': true}) : null,
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return PublicLeagueResponse.fromJson(data);
  }

  /// GET /lubowa/v1/public/leagues/<code>/results?date=YYYY-MM-DD
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<PublicResultsResponse> getPublicResults(String code, {String? date, bool forceRefresh = false}) async {
    final String path = '${AppConstants.pathLubowaPublicLeague}/${Uri.encodeComponent(code)}/results';
    final Response<Map<String, dynamic>> response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: date != null ? <String, String>{'date': date} : null,
      options: forceRefresh ? Options(extra: <String, Object>{'dio_cache_force_refresh': true}) : null,
    );
    final Map<String, dynamic>? data = response.data;
    if (data == null) {
      throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    }
    return PublicResultsResponse.fromJson(data);
  }
}

