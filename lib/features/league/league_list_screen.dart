import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lubowa_sports_park/core/cache/local_cache.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/league_detail_screen.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

class LeagueListScreen extends StatefulWidget {
  const LeagueListScreen({
    super.key,
    required this.repository,
    required this.filterManaged,
    this.managedIds = const [],
    this.ledTeamIds = const [],
  });

  final LeagueRepository repository;
  final bool filterManaged;
  final List<int> managedIds;
  final List<int> ledTeamIds;

  @override
  State<LeagueListScreen> createState() => _LeagueListScreenState();
}

class _LeagueListScreenState extends State<LeagueListScreen> {
  int _reloadToken = 0;

  Future<LeagueListState> _loadLeagues(BuildContext context) async {
    final repo = widget.repository;
    try {
      final list = await repo.getLeagues(forceRefresh: true);
      final prefs = await SharedPreferences.getInstance();
      await LocalCache(prefs).setList(
        LocalCache.leaguesKey,
        list.map((l) => l.toJson()).toList(),
      );
      return LeagueListState(leagues: list, error: null);
    } catch (e) {
      return LeagueListState(leagues: const <LeagueModel>[], error: e.toString());
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reloadToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.filterManaged ? 'Leagues I manage' : 'Teams I lead';
    return FutureProvider<LeagueListState>(
      key: ValueKey<int>(_reloadToken),
      initialData: LeagueListState(leagues: const <LeagueModel>[], error: null),
      create: (ctx) => _loadLeagues(ctx),
      child: _LeagueListView(
        title: title,
        filterManaged: widget.filterManaged,
        managedIds: widget.managedIds,
        repository: widget.repository,
        onRefresh: _refresh,
      ),
    );
  }
}

class LeagueListState {
  LeagueListState({required this.leagues, this.error});

  final List<LeagueModel> leagues;
  final String? error;
}

class _LeagueListView extends StatelessWidget {
  const _LeagueListView({
    required this.title,
    required this.filterManaged,
    required this.managedIds,
    required this.repository,
    required this.onRefresh,
  });

  final String title;
  final bool filterManaged;
  final List<int> managedIds;
  final LeagueRepository repository;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LeagueListState>();
    final loading = state.leagues.isEmpty && state.error == null;
    return _LeagueListScaffold(
      title: title,
      filterManaged: filterManaged,
      managedIds: managedIds,
      leagues: state.leagues,
      loading: loading,
      error: state.error,
      repository: repository,
      onRefresh: onRefresh,
    );
  }
}

class _LeagueListScaffold extends StatefulWidget {
  const _LeagueListScaffold({
    required this.title,
    required this.filterManaged,
    required this.managedIds,
    required this.leagues,
    required this.loading,
    required this.error,
    required this.repository,
    required this.onRefresh,
  });

  final String title;
  final bool filterManaged;
  final List<int> managedIds;
  final List<LeagueModel> leagues;
  final bool loading;
  final String? error;
  final LeagueRepository repository;
  final Future<void> Function() onRefresh;

  @override
  State<_LeagueListScaffold> createState() => _LeagueListScaffoldState();
}

class _LeagueListScaffoldState extends State<_LeagueListScaffold> {
  Future<bool> _confirmDeleteLeague(LeagueModel league) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete league'),
        content: Text(
          'Delete ${league.name}? This cannot be undone.',
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
      await widget.repository.deleteLeague(league.id);
      if (!mounted) return false;
      messenger.showSnackBar(const SnackBar(content: Text('League deleted')));
      await widget.onRefresh();
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
    final allLeagues = widget.leagues;
    final filteredLeagues = widget.filterManaged
        ? allLeagues.where((l) => widget.managedIds.contains(l.id)).toList()
        : allLeagues;

    if (widget.loading && allLeagues.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: FootballLoader()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: filteredLeagues.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.emoji_events_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 24),
                  Text(
                    widget.filterManaged ? 'No leagues yet' : 'No teams yet',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.filterManaged
                        ? 'Create a league from the Leagues tab, or ask park staff to add you as a league manager.'
                        : 'You\'ll see leagues here once you\'re set as a team leader.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filteredLeagues.length,
                itemBuilder: (_, i) {
                  final l = filteredLeagues[i];
                  final card = Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        fadeSlideRoute(builder: (_) => LeagueDetailScreen(league: l, repository: widget.repository)),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.emoji_events, color: colorScheme.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.name, style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Code: ${l.code}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (!widget.filterManaged) {
                    return card;
                  }
                  return Dismissible(
                    key: ValueKey<int>(l.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDeleteLeague(l),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                    ),
                    child: card,
                  );
                },
              ),
      ),
    );
  }
}

