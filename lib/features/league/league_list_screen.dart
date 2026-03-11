import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_detail_screen.dart';
import 'league_repository.dart';
import 'models/league.dart';

class LeagueListScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final title = filterManaged ? 'Leagues I manage' : 'Teams I lead';
    return Provider<LeagueRepository>.value(
      value: repository,
      child: StreamProvider<List<LeagueModel>>.value(
        initialData: const <LeagueModel>[],
        value: repository.getLeaguesStream(),
        child: _LeagueListScaffold(
          title: title,
          filterManaged: filterManaged,
          managedIds: managedIds,
        ),
      ),
    );
  }
}

class _LeagueListScaffold extends StatelessWidget {
  const _LeagueListScaffold({
    required this.title,
    required this.filterManaged,
    required this.managedIds,
  });

  final String title;
  final bool filterManaged;
  final List<int> managedIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repository = context.read<LeagueRepository>();
    final allLeagues = context.watch<List<LeagueModel>>();
    final leagues = filterManaged
        ? allLeagues.where((l) => managedIds.contains(l.id)).toList()
        : allLeagues;

    if (allLeagues.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: FootballLoader()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async {
          // Underlying stream polls every few seconds; wait briefly to hint refresh.
          await Future<void>.delayed(const Duration(seconds: 1));
        },
        child: leagues.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.emoji_events_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 24),
                  Text(
                    filterManaged ? 'No leagues yet' : 'No teams yet',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filterManaged
                        ? 'Create a league from the Leagues tab, or ask park staff to add you as a league manager.'
                        : 'You\'ll see leagues here once you\'re set as a team leader.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: leagues.length,
                itemBuilder: (_, i) {
                  final l = leagues[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        fadeSlideRoute(builder: (_) => LeagueDetailScreen(league: l, repository: repository)),
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
                },
              ),
      ),
    );
  }
}

