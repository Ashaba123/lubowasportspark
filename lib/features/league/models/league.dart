/// League (minimal) for list and public view.
class LeagueModel {
  const LeagueModel({
    required this.id,
    required this.name,
    required this.code,
    this.legs = 1,
    this.createdBy,
    this.createdAt,
  });

  final int id;
  final String name;
  final String code;
  final int legs;
  final int? createdBy;
  final String? createdAt;

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory LeagueModel.fromJson(Map<String, dynamic> json) => LeagueModel(
        id: _toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        legs: _toInt(json['legs']) == 0 ? 1 : _toInt(json['legs']),
        createdBy: _optionalInt(json['created_by']),
        createdAt: json['created_at'] as String?,
      );

  static int? _optionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Team (minimal).
class TeamModel {
  const TeamModel({required this.id, required this.name, this.leaderUserId});

  final int id;
  final String name;
  final int? leaderUserId;

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: LeagueModel._toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        leaderUserId: LeagueModel._optionalInt(json['leader_user_id']),
      );
}

/// Player (minimal).
class PlayerModel {
  const PlayerModel({required this.id, required this.name, this.goals = 0, this.userId});

  final int id;
  final String name;
  final int goals;
  final int? userId;

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
        id: LeagueModel._toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        goals: LeagueModel._optionalInt(json['goals']) ?? 0,
        userId: LeagueModel._optionalInt(json['user_id']),
      );
}

/// Fixture (match).
class FixtureModel {
  const FixtureModel({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeTeamName,
    this.awayTeamName,
    this.homeGoals,
    this.awayGoals,
    this.matchDate,
    this.matchTime,
    this.startedAt,
    this.resultConfirmed = 0,
    this.sortOrder,
  });

  final int id;
  final int homeTeamId;
  final int awayTeamId;
  final String? homeTeamName;
  final String? awayTeamName;
  final int? homeGoals;
  final int? awayGoals;
  final String? matchDate;
  final String? matchTime;
  final bool? startedAt;
  final int resultConfirmed;
  final int? sortOrder;

  factory FixtureModel.fromJson(Map<String, dynamic> json) => FixtureModel(
        id: LeagueModel._toInt(json['id']),
        homeTeamId: LeagueModel._toInt(json['home_team_id']),
        awayTeamId: LeagueModel._toInt(json['away_team_id']),
        homeTeamName: json['home_team_name'] as String?,
        awayTeamName: json['away_team_name'] as String?,
        homeGoals: LeagueModel._optionalInt(json['home_goals']),
        awayGoals: LeagueModel._optionalInt(json['away_goals']),
        matchDate: json['match_date'] as String?,
        matchTime: json['match_time'] as String?,
        startedAt: json['started_at'] == true || json['started_at'] == 1,
        resultConfirmed: LeagueModel._optionalInt(json['result_confirmed']) ?? 0,
        sortOrder: LeagueModel._optionalInt(json['sort_order']),
      );

  bool get isFullTime => resultConfirmed == 1;
}

/// Standings row (team, points, W/D/L).
class StandingsRow {
  const StandingsRow({
    required this.teamId,
    required this.teamName,
    required this.points,
    required this.won,
    required this.drawn,
    required this.lost,
  });

  final int teamId;
  final String teamName;
  final int points;
  final int won;
  final int drawn;
  final int lost;

  factory StandingsRow.fromJson(Map<String, dynamic> json) => StandingsRow(
        teamId: LeagueModel._toInt(json['team_id']),
        teamName: (json['team_name'] as String?) ?? '',
        points: LeagueModel._optionalInt(json['points']) ?? 0,
        won: LeagueModel._optionalInt(json['won']) ?? 0,
        drawn: LeagueModel._optionalInt(json['drawn']) ?? 0,
        lost: LeagueModel._optionalInt(json['lost']) ?? 0,
      );
}

/// Top scorer entry.
class TopScorerEntry {
  const TopScorerEntry({required this.playerId, required this.playerName, required this.goals, this.teamName});

  final int playerId;
  final String playerName;
  final int goals;
  final String? teamName;

  factory TopScorerEntry.fromJson(Map<String, dynamic> json) => TopScorerEntry(
        playerId: LeagueModel._toInt(json['player_id']),
        playerName: (json['player_name'] as String?) ?? '',
        goals: LeagueModel._optionalInt(json['goals']) ?? 0,
        teamName: json['team_name'] as String?,
      );
}

/// GET /lubowa/v1/public/leagues/<code> response.
class PublicLeagueResponse {
  const PublicLeagueResponse({
    required this.league,
    required this.standings,
    required this.fixtures,
    this.topScorers = const [],
  });

  final LeagueModel league;
  final List<StandingsRow> standings;
  final List<FixtureModel> fixtures;
  final List<TopScorerEntry> topScorers;

  factory PublicLeagueResponse.fromJson(Map<String, dynamic> json) {
    final leagueObj = json['league'] as Map<String, dynamic>?;
    final standingsList = json['standings'] as List<dynamic>?;
    final fixturesList = json['fixtures'] as List<dynamic>?;
    final topList = json['top_scorers'] as List<dynamic>?;
    return PublicLeagueResponse(
      league: leagueObj != null ? LeagueModel.fromJson(leagueObj) : const LeagueModel(id: 0, name: '', code: ''),
      standings: standingsList?.map((e) => StandingsRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      fixtures: fixturesList?.map((e) => FixtureModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      topScorers: topList?.map((e) => TopScorerEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

/// GET /lubowa/v1/public/leagues/<code>/results?date= response.
class PublicResultsResponse {
  const PublicResultsResponse({
    required this.league,
    required this.date,
    required this.results,
  });

  final LeagueModel league;
  final String date;
  final List<FixtureModel> results;

  factory PublicResultsResponse.fromJson(Map<String, dynamic> json) {
    final leagueObj = json['league'] as Map<String, dynamic>?;
    final resultsList = json['results'] as List<dynamic>?;
    return PublicResultsResponse(
      league: leagueObj != null ? LeagueModel.fromJson(leagueObj) : const LeagueModel(id: 0, name: '', code: ''),
      date: (json['date'] as String?) ?? '',
      results: resultsList?.map((e) => FixtureModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

/// GET /lubowa/v1/me/league_roles response.
class LeagueRoles {
  const LeagueRoles({
    this.canCreateLeague = false,
    this.managedLeagueIds = const [],
    this.ledTeamIds = const [],
  });

  final bool canCreateLeague;
  final List<int> managedLeagueIds;
  final List<int> ledTeamIds;

  factory LeagueRoles.fromJson(Map<String, dynamic> json) {
    final managed = json['managed_league_ids'] as List<dynamic>?;
    final led = json['led_team_ids'] as List<dynamic>?;
    return LeagueRoles(
      canCreateLeague: json['can_create_league'] == true,
      managedLeagueIds: managed?.map((e) => LeagueModel._toInt(e)).where((v) => v != 0).toList() ?? [],
      ledTeamIds: led?.map((e) => LeagueModel._toInt(e)).where((v) => v != 0).toList() ?? [],
    );
  }
}

/// GET /lubowa/v1/me/player response (career goals).
class MePlayer {
  const MePlayer({
    required this.id,
    required this.name,
    required this.teamId,
    required this.goals,
    this.teamName,
    this.leagueId,
    this.leagueName,
  });

  final int id;
  final String name;
  final int teamId;
  final int goals;
  final String? teamName;
  final int? leagueId;
  final String? leagueName;

  factory MePlayer.fromJson(Map<String, dynamic> json) => MePlayer(
        id: LeagueModel._toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        teamId: LeagueModel._toInt(json['team_id']),
        goals: LeagueModel._optionalInt(json['goals']) ?? 0,
        teamName: json['team_name'] as String?,
        leagueId: LeagueModel._optionalInt(json['league_id']),
        leagueName: json['league_name'] as String?,
      );
}
