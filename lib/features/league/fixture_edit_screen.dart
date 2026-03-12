import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/fixture_goals_screen.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

class FixtureEditScreen extends StatefulWidget {
  const FixtureEditScreen({
    super.key,
    required this.fixture,
    required this.repository,
    required this.onSaved,
  });

  final FixtureModel fixture;
  final LeagueRepository repository;
  final void Function(FixtureModel updated) onSaved;

  @override
  State<FixtureEditScreen> createState() => _FixtureEditScreenState();
}

class _FixtureEditScreenState extends State<FixtureEditScreen> {
  late final TextEditingController _homeCtrl;
  late final TextEditingController _awayCtrl;
  late bool _started;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: '${widget.fixture.homeGoals ?? 0}');
    _awayCtrl = TextEditingController(text: '${widget.fixture.awayGoals ?? 0}');
    _started = widget.fixture.isStarted;
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  int get _homeGoals => int.tryParse(_homeCtrl.text) ?? 0;
  int get _awayGoals => int.tryParse(_awayCtrl.text) ?? 0;

  Future<void> _save() async {
    if (widget.fixture.isFullTime) return;
    final h = _homeGoals;
    final a = _awayGoals;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateFixture(
        widget.fixture.id,
        homeGoals: h,
        awayGoals: a,
      );
      if (!mounted) return;
      if (updated.isStarted &&
          ((updated.homeGoals ?? 0) > 0 || (updated.awayGoals ?? 0) > 0)) {
        await _showAssignGoalsDialog(updated);
      }
      if (mounted) {
        widget.onSaved(updated);
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(userFriendlyApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markFullTime() async {
    if (widget.fixture.isFullTime) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!_started) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Start the match first')),
      );
      return;
    }
    final h = _homeGoals;
    final a = _awayGoals;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateFixture(
        widget.fixture.id,
        homeGoals: h,
        awayGoals: a,
        resultConfirmed: 1,
      );
      if (!mounted) return;
      if (updated.isStarted &&
          ((updated.homeGoals ?? 0) > 0 || (updated.awayGoals ?? 0) > 0)) {
        await _showAssignGoalsDialog(updated);
      }
      if (mounted) {
        widget.onSaved(updated);
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(userFriendlyApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startMatch() async {
    if (_started || widget.fixture.isFullTime) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateFixture(
        widget.fixture.id,
        startedAt: true,
      );
      if (!mounted) return;
      setState(() {
        _started = updated.isStarted;
      });
      widget.onSaved(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Match started')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(userFriendlyApiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAssignGoalsDialog(FixtureModel updated) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AssignGoalsDialog(
        fixture: updated,
        repository: widget.repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit fixture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${widget.fixture.homeTeamName ?? "Home"} vs ${widget.fixture.awayTeamName ?? "Away"}',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.fixture.isFullTime) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Full time — score locked',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ] else if (_started) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Match in progress',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.secondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                fadeSlideRoute(
                  builder: (_) => FixtureGoalsScreen(
                    fixture: widget.fixture,
                    repository: widget.repository,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.sports_score),
            label: const Text('Goal log'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
          if (!widget.fixture.isFullTime) ...[
            const SizedBox(height: 24),
            if (!_started) ...[
              FilledButton.tonal(
                onPressed: _saving ? null : _startMatch,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
                child: _saving
                    ? const FootballLoader(size: 22)
                    : const Text('Start match'),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _homeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.fixture.homeTeamName ?? 'Home',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '–',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _awayCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.fixture.awayTeamName ?? 'Away',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
              child: _saving
                  ? const FootballLoader(size: 22)
                  : const Text('Save score'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _markFullTime,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text('Mark full time'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog to assign fixture goals to players (home/away) after saving score.
class _AssignGoalsDialog extends StatefulWidget {
  const _AssignGoalsDialog({
    required this.fixture,
    required this.repository,
  });

  final FixtureModel fixture;
  final LeagueRepository repository;

  @override
  State<_AssignGoalsDialog> createState() => _AssignGoalsDialogState();
}

class _AssignGoalsDialogState extends State<_AssignGoalsDialog> {
  List<PlayerModel> _homePlayers = [];
  List<PlayerModel> _awayPlayers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final home = await widget.repository.getTeamPlayers(
        widget.fixture.homeTeamId,
        forceRefresh: true,
      );
      final away = await widget.repository.getTeamPlayers(
        widget.fixture.awayTeamId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _homePlayers = home..sort((a, b) => a.name.compareTo(b.name));
        _awayPlayers = away..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addGoalForTeam(bool isHome) async {
    final players = isHome ? _homePlayers : _awayPlayers;
    if (players.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add players to this team first')),
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
          title: Text(
              'Add goals — ${isHome ? widget.fixture.homeTeamName ?? "Home" : widget.fixture.awayTeamName ?? "Away"}'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals recorded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyApiErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeGoals = widget.fixture.homeGoals ?? 0;
    final awayGoals = widget.fixture.awayGoals ?? 0;

    return AlertDialog(
      title: const Text('Record who scored? (optional)'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: FootballLoader(size: 32)),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (homeGoals > 0) ...[
                    Text(
                      '${widget.fixture.homeTeamName ?? "Home"} ($homeGoals ${homeGoals == 1 ? "goal" : "goals"})',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _addGoalForTeam(true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add goal'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (awayGoals > 0) ...[
                    Text(
                      '${widget.fixture.awayTeamName ?? "Away"} ($awayGoals ${awayGoals == 1 ? "goal" : "goals"})',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _addGoalForTeam(false),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add goal'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'You can also use Goal log from the fixture to add or edit later.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
