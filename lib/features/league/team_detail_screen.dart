import 'package:flutter/material.dart';

import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_repository.dart';
import 'models/league.dart';
import 'player_view_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    super.key,
    required this.league,
    required this.team,
    required this.repository,
  });

  final LeagueModel league;
  final TeamModel team;
  final LeagueRepository repository;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  List<PlayerModel> _players = [];
  bool _loading = true;
  late String _teamName;

  @override
  void initState() {
    super.initState();
    _teamName = widget.team.name;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getTeamPlayers(widget.team.id, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _players = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openPlayer(BuildContext context, PlayerModel player) {
    Navigator.of(context)
        .push<bool>(
      fadeSlideRoute(
        builder: (_) => PlayerViewScreen(
          player: player,
          teamName: _teamName,
          leagueName: widget.league.name,
          repository: widget.repository,
        ),
      ),
    )
        .then((deleted) {
      if (deleted == true && mounted) {
        setState(() {
          _players = _players.where((p) => p.id != player.id).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_teamName)),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_teamName),
        actions: [
          IconButton(
            tooltip: 'Rename team',
            icon: const Icon(Icons.edit),
            onPressed: _showRenameTeamDialog,
          ),
          IconButton(
            tooltip: 'Delete team',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDeleteTeam,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups, color: colorScheme.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_teamName, style: theme.textTheme.titleLarge),
                          Text(
                            '${_players.length}/8 players',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Players', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._players.map(
                    (p) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          '${p.goals}',
                          style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                      title: Text(p.name, style: theme.textTheme.bodyLarge),
                      subtitle: Text(
                        '${p.goals} goals',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPlayer(context, p),
                    ),
                  ),
                ],
              ),
            ),
            if (_players.length < 8) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showAddPlayer(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add player'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlayer(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newPlayer = await widget.repository.addPlayer(
        widget.team.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _players = [..._players, newPlayer];
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Player added')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showRenameTeamDialog() async {
    final nameCtrl = TextEditingController(text: _teamName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename team'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Team name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await widget.repository.updateTeam(
        widget.team.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _teamName = updated.name;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Team updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmDeleteTeam() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team'),
        content: const Text('Are you sure you want to delete this team? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.deleteTeam(widget.team.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Team deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

