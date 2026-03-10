import 'package:flutter/material.dart';

import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_repository.dart';
import 'models/league.dart';
import 'team_detail_screen.dart';

class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({super.key, required this.league, required this.repository});

  final LeagueModel league;
  final LeagueRepository repository;

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  List<TeamModel> _teams = [];
  bool _loading = true;
  late String _leagueName;

  @override
  void initState() {
    super.initState();
    _leagueName = widget.league.name;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final teams = await widget.repository.getTeams(widget.league.id, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_leagueName)),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_leagueName),
        actions: [
          IconButton(
            tooltip: 'Rename league',
            icon: const Icon(Icons.edit),
            onPressed: _showRenameLeagueDialog,
          ),
          IconButton(
            tooltip: 'Delete league',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDeleteLeague,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_leagueName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${widget.league.code}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Teams', style: theme.textTheme.titleLarge),
                const SizedBox(width: 8),
                Text(
                  '(${_teams.length})',
                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddTeam(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add team'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._teams.map(
                    (t) => ListTile(
                      leading: Icon(Icons.groups_outlined, color: colorScheme.primary),
                      title: Text(t.name, style: theme.textTheme.bodyLarge),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openTeam(context, t),
                    ),
                  ),
                  if (_teams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Add at least 2 teams to generate fixtures.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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

  void _openTeam(BuildContext context, TeamModel team) {
    Navigator.of(context)
        .push<bool>(
      fadeSlideRoute(
        builder: (_) => TeamDetailScreen(
          league: widget.league,
          team: team,
          repository: widget.repository,
        ),
      ),
    )
        .then((deleted) {
      if (deleted == true && mounted) {
        setState(() {
          _teams = _teams.where((t) => t.id != team.id).toList();
        });
      }
    });
  }

  Future<void> _showAddTeam(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add team'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final newTeam = await widget.repository.addTeam(
        widget.league.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _teams = [..._teams, newTeam];
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Team added')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showRenameLeagueDialog() async {
    final nameCtrl = TextEditingController(text: _leagueName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename league'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'League name'),
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
      final updated = await widget.repository.updateLeague(
        widget.league.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _leagueName = updated.name;
      });
      messenger.showSnackBar(const SnackBar(content: Text('League updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmDeleteLeague() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete league'),
        content: const Text('Are you sure you want to delete this league? This cannot be undone.'),
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
      await widget.repository.deleteLeague(widget.league.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('League deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

