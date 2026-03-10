import 'package:flutter/material.dart';

import '../../shared/football_loader.dart';
import 'league_repository.dart';
import 'models/league.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      setState(() {
        _goals = _goals.where((g) => g.id != entry.id).toList();
      });
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
