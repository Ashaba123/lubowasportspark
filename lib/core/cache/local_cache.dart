import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin SharedPreferences wrapper that stores JSON-encoded lists keyed by
/// entity type + optional ID. Used to show last-known data while the API
/// reloads, and to survive navigation back/forward within the same session.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  // —— Key helpers ——

  static const String leaguesKey = 'cache_leagues';
  static String teamsKey(int leagueId) => 'cache_teams_$leagueId';
  static String playersKey(int teamId) => 'cache_players_$teamId';
  static String fixturesKey(int leagueId) => 'cache_fixtures_$leagueId';
  static String goalsKey(int fixtureId) => 'cache_goals_$fixtureId';
  static String bookingsKey(String email) =>
      'cache_bookings_${email.toLowerCase()}';

  // —— Read ——

  /// Returns the cached list for [key], or empty if nothing is stored.
  List<Map<String, dynamic>> getList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // —— Write ——

  /// Saves [data] as a JSON-encoded list under [key].
  Future<void> setList(
    String key,
    List<Map<String, dynamic>> data,
  ) =>
      _prefs.setString(key, jsonEncode(data));

  /// Removes the cached value for [key].
  Future<void> remove(String key) => _prefs.remove(key);
}
