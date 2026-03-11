import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/cache/local_cache.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

/// List, add, update, and delete goal log entries for a fixture.
class FixtureGoalsScreen extends StatefulWidget {
  const FixtureGoalsScreen({
    super.key,
    required this.fixture,
    required this.repository,
  });

  final FixtureModel fixture;
  final LeagueRepository repository;

  @override
  State<FixtureGoalsScreen> createState() => _FixtureGoalsScreenState();
}

class _FixtureGoalsScreenState extends State<FixtureGoalsScreen> {
  List<GoalLogEntry> _goals = [];
  Map<int, PlayerModel> _playerMap = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = LocalCache(prefs);
    final goalsKey = LocalCache.goalsKey(widget.fixture.id);
    final homeKey = LocalCache.playersKey(widget.fixture.homeTeamId);
    final awayKey = LocalCache.playersKey(widget.fixture.awayTeamId);

    final cachedGoals = cache.getList(goalsKey).map(GoalLogEntry.fromJson).toList();
    final cachedHomePlayers = cache.getList(homeKey).map(PlayerModel.fromJson).toList();
    final cachedAwayPlayers = cache.getList(awayKey).map(PlayerModel.fromJson).toList();

    if ((cachedGoals.isNotEmpty || cachedHomePlayers.isNotEmpty || cachedAwayPlayers.isNotEmpty) && mounted) {
      final map = <int, PlayerModel>{
        for (final p in cachedHomePlayers) p.id: p,
        for (final p in cachedAwayPlayers) p.id: p,
      };
      setState(() {
        _goals = cachedGoals;
        _playerMap = map;
        _loading = false;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final goals = await widget.repository.getFixtureGoals(
        widget.fixture.id,
        forceRefresh: true,
      );
      final homePlayers = await widget.repository.getTeamPlayers(
        widget.fixture.homeTeamId,
        forceRefresh: true,
      );
      final awayPlayers = await widget.repository.getTeamPlayers(
        widget.fixture.awayTeamId,
        forceRefresh: true,
      );
      await cache.setList(goalsKey, goals.map((g) => g.toJson()).toList());
      await cache.setList(homeKey, homePlayers.map((p) => p.toJson()).toList());
      await cache.setList(awayKey, awayPlayers.map((p) => p.toJson()).toList());
      final map = <int, PlayerModel>{};
      for (final p in homePlayers) {
        map[p.id] = p;
      }
      for (final p in awayPlayers) {
        map[p.id] = p;
      }
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _playerMap = map;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  String _playerName(int playerId) =>
      _playerMap[playerId]?.name ?? 'Player $playerId';

  List<PlayerModel> get _allPlayers =>
      _playerMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _addGoal() async {
    final players = _allPlayers;
    if (players.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add players to teams first')),
        );
      }
      return;
    }
    PlayerModel? selected = players.first;
    final goalsCtrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add goals'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PlayerModel>(
                // ignore: deprecated_member_use
                value: selected,
                decoration: const InputDecoration(labelText: 'Player'),
                items: players
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selected = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: goalsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Goals'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(goalsCtrl.text.trim());
                if (n == null || n < 1 || selected == null) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || selected == null) return;
    final player = selected!;
    final n = int.tryParse(goalsCtrl.text.trim());
    if (n == null || n < 1) return;
    try {
      await widget.repository.recordGoals(
        widget.fixture.id,
        playerId: player.id,
        goals: n,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals recorded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editGoal(GoalLogEntry entry) async {
    final ctrl = TextEditingController(text: '${entry.goals}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit goals'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Goals'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim());
              if (n == null || n < 0) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = int.tryParse(ctrl.text.trim());
    if (n == null || n < 0) return;
    try {
      await widget.repository.updateFixtureGoal(
        fixtureId: widget.fixture.id,
        goalId: entry.id,
        goals: n,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal entry updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteGoal(GoalLogEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal entry'),
        content: const Text(
          'Remove this goal log entry? The player\'s total goals will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deleteFixtureGoal(
        fixtureId: widget.fixture.id,
        goalId: entry.id,
      );
      if (!mounted) return;
      final updated = _goals.where((g) => g.id != entry.id).toList();
      setState(() {
        _goals = updated;
      });
      SharedPreferences.getInstance().then(
        (prefs) => LocalCache(prefs).setList(
          LocalCache.goalsKey(widget.fixture.id),
          updated.map((g) => g.toJson()).toList(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Goal log'),
        ),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoal,
        icon: const Icon(Icons.add),
        label: const Text('Add goals'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${widget.fixture.homeTeamName ?? "Home"} vs ${widget.fixture.awayTeamName ?? "Away"}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_goals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No goal entries yet. Tap "Add goals" to record.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    ..._goals.map(
                      (e) => ListTile(
                        title: Text(_playerName(e.playerId)),
                        subtitle: Text('${e.goals} goals'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editGoal(e),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteGoal(e),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
