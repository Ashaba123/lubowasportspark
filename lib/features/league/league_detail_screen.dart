import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'fixtures_polling_notifier.dart';
import 'fixtures_screen.dart';
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
  List<FixtureModel> _fixtures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final teams = await widget.repository.getTeams(widget.league.id, forceRefresh: true);
      List<FixtureModel> fixtures = [];
      try {
        fixtures = await widget.repository.getFixtures(widget.league.id, forceRefresh: true);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _fixtures = fixtures;
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
        appBar: AppBar(title: Text(widget.league.name)),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.league.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.league.name, style: theme.textTheme.titleLarge),
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
            const SizedBox(height: 24),
            Text('Fixtures', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You (league creator) or park staff can generate fixtures. Needs at least 2 teams.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context)
                  .push(
                    fadeSlideRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => FixturesPollingNotifier(
                          leagueId: widget.league.id,
                          repository: widget.repository,
                          initialFixtures: _fixtures,
                        )..start(),
                        child: FixturesScreen(
                          league: widget.league,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                  )
                  .then((_) {
                if (mounted) _load();
              }),
              icon: const Icon(Icons.calendar_view_month),
              label: const Text('View fixtures'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }

  void _openTeam(BuildContext context, TeamModel team) {
    Navigator.of(context).push(
      fadeSlideRoute(
        builder: (_) => TeamDetailScreen(
          league: widget.league,
          team: team,
          repository: widget.repository,
        ),
      ),
    );
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
      await widget.repository.addTeam(widget.league.id, name: nameCtrl.text.trim());
      if (mounted) await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

