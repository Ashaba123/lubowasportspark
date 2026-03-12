import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

part 'repositories/public_leagues_repository.dart';
part 'repositories/league_roles_repository.dart';
part 'repositories/leagues_repository.dart';
part 'repositories/teams_repository.dart';
part 'repositories/players_repository.dart';
part 'repositories/fixtures_repository.dart';

/// League API: public (by code) and authenticated (manage). Uses [ApiClient] for base URL and optional JWT.
class LeagueRepository {
  LeagueRepository({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  static List<dynamic> listFromPaginated(dynamic raw) {
    if (raw == null) return <dynamic>[];
    if (raw is Map && raw.containsKey('data')) return raw['data'] as List<dynamic>? ?? <dynamic>[];
    if (raw is List) return raw;
    return <dynamic>[];
  }
}
