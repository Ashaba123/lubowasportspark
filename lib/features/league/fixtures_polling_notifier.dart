import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/local_cache.dart';
import 'league_repository.dart';
import 'models/league.dart';

/// Polls fixtures for a league so the screen updates when another user changes goals (or fixtures).
/// Start with [start]; call [refresh] for manual refresh (pull-to-refresh, after generate/reset/edit).
class FixturesPollingNotifier extends ChangeNotifier {
  FixturesPollingNotifier({
    required this.leagueId,
    required this.repository,
    List<FixtureModel> initialFixtures = const [],
  }) : _fixtures = List.from(initialFixtures);

  final int leagueId;
  final LeagueRepository repository;

  static const Duration pollInterval = Duration(seconds: 15);

  List<FixtureModel> _fixtures;
  bool _loading = true;
  Object? _error;
  Timer? _timer;

  List<FixtureModel> get fixtures => _fixtures;
  bool get loading => _loading;
  Object? get error => _error;

  /// Replace fixtures list with [list] and notify listeners immediately.
  /// Used after generate/reset so UI updates even if polling hasn't fired yet.
  void setFixtures(List<FixtureModel> list) {
    _fixtures = List.from(list);
    _loading = false;
    _error = null;
    notifyListeners();
    _persistFixtures(list);
  }

  /// Update a single [fixture] in the list and notify listeners.
  /// Used after editing score or marking full time so UI updates immediately.
  void updateFixture(FixtureModel fixture) {
    final index = _fixtures.indexWhere((f) => f.id == fixture.id);
    if (index == -1) return;
    _fixtures[index] = fixture;
    notifyListeners();
    _persistFixtures(_fixtures);
  }

  void start() {
    _loadFromCacheThenApi();
    _timer = Timer.periodic(pollInterval, (_) => _load());
  }

  Future<void> refresh() => _load();

  Future<void> _loadFromCacheThenApi() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = LocalCache(prefs).getList(LocalCache.fixturesKey(leagueId));
    if (cached.isNotEmpty && _fixtures.isEmpty) {
      _fixtures = cached.map(FixtureModel.fromJson).toList();
      _loading = false;
      notifyListeners();
    }
    await _load();
  }

  Future<void> _load() async {
    final isFirstLoad = _fixtures.isEmpty;
    if (isFirstLoad) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final list = await repository.getFixtures(leagueId, forceRefresh: true);
      if (_timer != null) {
        _fixtures = list;
        _loading = false;
        _error = null;
        notifyListeners();
        _persistFixtures(list);
      }
    } catch (e) {
      if (_timer != null) {
        _error = e;
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _persistFixtures(List<FixtureModel> list) {
    SharedPreferences.getInstance().then(
      (prefs) => LocalCache(prefs).setList(
        LocalCache.fixturesKey(leagueId),
        list.map((f) => f.toJson()).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
