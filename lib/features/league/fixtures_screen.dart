import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/api_error_message.dart';
import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'fixtures_polling_notifier.dart';
import 'fixture_edit_screen.dart';
import 'league_repository.dart';
import 'models/league.dart';

class FixturesScreen extends StatelessWidget {
  const FixturesScreen({
    super.key,
    required this.league,
    required this.repository,
  });

  final LeagueModel league;
  final LeagueRepository repository;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<FixturesPollingNotifier>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fixtures = notifier.fixtures;
    final loading = notifier.loading;

    return Scaffold(
      appBar: AppBar(title: Text('${league.name} — Fixtures')),
      backgroundColor: colorScheme.surface,
      body: loading && fixtures.isEmpty
          ? const Center(child: FootballLoader())
          : RefreshIndicator(
              onRefresh: () => context.read<FixturesPollingNotifier>().refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text('Generate fixtures', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final notifier = context.read<FixturesPollingNotifier>();
                          try {
                            await repository.generateFixtures(league.id);
                            await notifier.refresh();
                            if (context.mounted) {
                              messenger.showSnackBar(const SnackBar(content: Text('Fixtures generated')));
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(userFriendlyApiErrorMessage(e))),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Generate'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final notifier = context.read<FixturesPollingNotifier>();
                          try {
                            await repository.resetFixtures(league.id);
                            await notifier.refresh();
                            if (context.mounted) {
                              messenger.showSnackBar(const SnackBar(content: Text('Fixtures reset')));
                            }
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Needs at least 2 teams. You (league creator) or park staff can generate.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (fixtures.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No fixtures yet. Add teams in the league then tap Generate.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: fixtures
                            .map(
                              (f) => ListTile(
                                title: Text(
                                  '${f.homeTeamName ?? "?"} vs ${f.awayTeamName ?? "?"}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  '${f.homeGoals ?? 0} – ${f.awayGoals ?? 0}${f.isFullTime ? " (FT)" : ""}',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () {
                                  Navigator.of(context).push(
                                    fadeSlideRoute(
                                      builder: (_) => FixtureEditScreen(
                                        fixture: f,
                                        repository: repository,
                                        onSaved: () => context.read<FixturesPollingNotifier>().refresh(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

