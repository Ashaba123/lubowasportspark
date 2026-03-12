import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/fixtures_polling_notifier.dart';
import 'package:lubowa_sports_park/features/league/fixtures_screen.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';
import 'package:lubowa_sports_park/features/league/team_detail_screen.dart';

class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({
    super.key,
    required this.league,
    required this.repository,
  });

  final LeagueModel league;
  final LeagueRepository repository;

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  late String _leagueName;
  // The future driving the FutureBuilder. Reassigning this triggers a rebuild.
  late Future<List<TeamModel>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _leagueName = widget.league.name;
    _teamsFuture = _fetchTeams();
  }

  Future<List<TeamModel>> _fetchTeams() =>
      widget.repository.getTeams(widget.league.id, forceRefresh: true);

  /// Reassign the future so FutureBuilder re-runs the fetch.
  Future<void> _refresh() async {
    if (!mounted) return;
    final Future<List<TeamModel>> nextFuture = _fetchTeams();
    setState(() {
      _teamsFuture = nextFuture;
    });
    await nextFuture;
  }

  Future<bool> _confirmDeleteTeamFromList(TeamModel team) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team'),
        content: Text(
          'Delete ${team.name}? This cannot be undone.',
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
    if (ok != true || !mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.deleteTeam(team.id);
      if (!mounted) return false;
      messenger.showSnackBar(const SnackBar(content: Text('Team deleted')));
      await _refresh();
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      body: FutureBuilder<List<TeamModel>>(
        future: _teamsFuture,
        builder: (context, snapshot) {
          // Show full-screen loader only on the very first load (no data yet).
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: FootballLoader());
          }

          final teams = snapshot.data ?? [];
          final error = snapshot.hasError
              ? userFriendlyApiErrorMessage(snapshot.error!)
              : null;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // League info card
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),

                // Inline error (keeps list visible)
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ),
                ],

                // Subtle loading indicator while refreshing with existing data
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.hasData) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],

                const SizedBox(height: 24),

                // Teams header
                Row(
                  children: [
                    Text('Teams', style: theme.textTheme.titleLarge),
                    const SizedBox(width: 8),
                    Text(
                      '(${teams.length})',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _showAddTeam(context, teams),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add team'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Teams list
                Card(
                  child: Column(
                    children: [
                      ...teams.map((t) {
                        return Dismissible(
                          key: ValueKey<int>(t.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteTeamFromList(t),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: colorScheme.errorContainer,
                            child: Icon(
                              Icons.delete_outline,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.groups_outlined,
                                color: colorScheme.primary),
                            title:
                                Text(t.name, style: theme.textTheme.bodyLarge),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openTeam(context, t),
                          ),
                        );
                      }),
                      if (teams.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Add at least 2 teams to generate fixtures.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Fixtures header
                Row(
                  children: [
                    Text('Fixtures', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: teams.length < 2
                          ? null
                          : () => _openFixtures(context),
                      icon: const Icon(Icons.calendar_month, size: 20),
                      label: const Text('Open fixtures'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (teams.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Add at least 2 teams to generate fixtures.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.sports_soccer_outlined,
                          color: colorScheme.primary),
                      title: Text(
                        'Generate fixtures, edit scores, add goals, mark full time',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openFixtures(context),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openFixtures(BuildContext context) {
    Navigator.of(context).push(
      fadeSlideRoute(
        builder: (_) => ChangeNotifierProvider<FixturesPollingNotifier>(
          create: (_) => FixturesPollingNotifier(
            leagueId: widget.league.id,
            repository: widget.repository,
          )..start(),
          child: FixturesScreen(
            league: widget.league,
            repository: widget.repository,
          ),
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
    ).then((_) => _refresh()); // ✅ always refresh — covers rename, delete, etc.
  }

  Future<void> _showAddTeam(
      BuildContext context, List<TeamModel> currentTeams) async {
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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
      await widget.repository.addTeam(
        widget.league.id,
        name: nameCtrl.text.trim(),
      );
      await _refresh(); // ✅ re-fetch so new team appears from server
      messenger.showSnackBar(const SnackBar(content: Text('Team added')));
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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
      setState(() => _leagueName = updated.name);
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
        content: const Text(
            'Are you sure you want to delete this league? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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