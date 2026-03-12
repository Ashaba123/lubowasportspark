import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/cache/local_cache.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';
import 'package:lubowa_sports_park/features/league/player_view_screen.dart';

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
  late String _teamName;
  // The future driving the FutureBuilder. Reassigning triggers a rebuild.
  late Future<List<PlayerModel>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _teamName = widget.team.name;
    _playersFuture = _fetchPlayers();
  }

  /// Fetches players fresh from server and updates the local cache.
  Future<List<PlayerModel>> _fetchPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = LocalCache(prefs);
    final cacheKey = LocalCache.playersKey(widget.team.id);

    final list = await widget.repository.getTeamPlayers(
      widget.team.id,
      forceRefresh: true,
    );
    await cache.setList(cacheKey, list.map((p) => p.toJson()).toList());
    return list;
  }

  /// Reassign the future so FutureBuilder re-runs the fetch.
  Future<void> _refresh() async {
    if (!mounted) return;
    final Future<List<PlayerModel>> nextFuture = _fetchPlayers();
    setState(() {
      _playersFuture = nextFuture;
    });
    await nextFuture;
  }

  Future<bool> _confirmDeletePlayerFromList(PlayerModel player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete player'),
        content: Text(
          'Delete ${player.name}? This cannot be undone.',
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
      await widget.repository.deletePlayer(player.id);
      if (!mounted) return false;
      messenger.showSnackBar(const SnackBar(content: Text('Player deleted')));
      await _refresh();
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return false;
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
        .then((_) => _refresh()); // ✅ always refresh on return
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      body: FutureBuilder<List<PlayerModel>>(
        future: _playersFuture,
        builder: (context, snapshot) {
          // Full-screen loader only on the very first load (no data yet)
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: FootballLoader());
          }

          final players = snapshot.data ?? [];
          final error = snapshot.hasError
              ? userFriendlyApiErrorMessage(snapshot.error!)
              : null;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Inline error — keeps the list visible
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ),

                // Subtle progress bar while refreshing with existing data
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.hasData) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                ],

                // Team summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.groups,
                            color: colorScheme.primary, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_teamName,
                                  style: theme.textTheme.titleLarge),
                              Text(
                                '${players.length}/8 players',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
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

                // Players list
                Card(
                  child: Column(
                    children: [
                      if (players.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No players yet. Add up to 8.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ...players.map((p) {
                        return Dismissible(
                          key: ValueKey<int>(p.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeletePlayerFromList(p),
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
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                '${p.goals}',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ),
                            title:
                                Text(p.name, style: theme.textTheme.bodyLarge),
                            subtitle: Text(
                              '${p.goals} goals',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openPlayer(context, p),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Add player button (only if under limit)
                if (players.length < 8) ...[
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
          );
        },
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
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.addPlayer(
        widget.team.id,
        name: nameCtrl.text.trim(),
      );
      await _refresh(); // ✅ re-fetch so new player appears from server
      messenger.showSnackBar(const SnackBar(content: Text('Player added')));
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
      final updated = await widget.repository.updateTeam(
        widget.team.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _teamName = updated.name);
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
        content: const Text(
            'Are you sure you want to delete this team? This cannot be undone.'),
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
      await widget.repository.deleteTeam(widget.team.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Team deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}