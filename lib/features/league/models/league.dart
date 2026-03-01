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

  factory LeagueModel.fromJson(Map<String, dynamic> json) => LeagueModel(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        legs: json['legs'] as int? ?? 1,
        createdBy: json['created_by'] as int?,
        createdAt: json['created_at'] as String?,
      );
}

/// Team (minimal).
class TeamModel {
  const TeamModel({required this.id, required this.name, this.leaderUserId});

  final int id;
  final String name;
  final int? leaderUserId;

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        leaderUserId: json['leader_user_id'] as int?,
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
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        goals: json['goals'] as int? ?? 0,
        userId: json['user_id'] as int?,
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
        id: json['id'] as int,
        homeTeamId: json['home_team_id'] as int,
        awayTeamId: json['away_team_id'] as int,
        homeTeamName: json['home_team_name'] as String?,
        awayTeamName: json['away_team_name'] as String?,
        homeGoals: json['home_goals'] as int?,
        awayGoals: json['away_goals'] as int?,
        matchDate: json['match_date'] as String?,
        matchTime: json['match_time'] as String?,
        startedAt: json['started_at'] == true || json['started_at'] == 1,
        resultConfirmed: json['result_confirmed'] as int? ?? 0,
        sortOrder: json['sort_order'] as int?,
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
        teamId: json['team_id'] as int,
        teamName: (json['team_name'] as String?) ?? '',
        points: json['points'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        drawn: json['drawn'] as int? ?? 0,
        lost: json['lost'] as int? ?? 0,
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
        playerId: json['player_id'] as int,
        playerName: (json['player_name'] as String?) ?? '',
        goals: json['goals'] as int? ?? 0,
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
      managedLeagueIds: managed?.map((e) => e as int).toList() ?? [],
      ledTeamIds: led?.map((e) => e as int).toList() ?? [],
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
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        teamId: json['team_id'] as int,
        goals: json['goals'] as int? ?? 0,
        teamName: json['team_name'] as String?,
        leagueId: json['league_id'] as int?,
        leagueName: json['league_name'] as String?,
      );
}
