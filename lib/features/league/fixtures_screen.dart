import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/fixtures_polling_notifier.dart';
import 'package:lubowa_sports_park/features/league/fixture_edit_screen.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate fixtures',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Needs at least 2 teams. You (league creator) or park staff can generate.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final fixturesNotifier = context.read<FixturesPollingNotifier>();
                                  try {
                                    final generated = await repository.generateFixtures(league.id);
                                    if (generated.isNotEmpty) {
                                      fixturesNotifier.setFixtures(generated);
                                    } else {
                                      await fixturesNotifier.refresh();
                                    }
                                    if (context.mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Fixtures generated'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(userFriendlyApiErrorMessage(e)),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Generate'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final fixturesNotifier = context.read<FixturesPollingNotifier>();
                                  try {
                                    await repository.resetFixtures(league.id);
                                    fixturesNotifier.setFixtures(const []);
                                    await fixturesNotifier.refresh();
                                    if (context.mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Fixtures reset'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                    Column(
                      children: [
                        Card(
                          color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                          child: ListTile(
                            leading: Icon(
                              Icons.touch_app_outlined,
                              color: colorScheme.secondary,
                            ),
                            title: Text(
                              'Tap a fixture to continue',
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              'Open a fixture to start the match, save score, and mark full time.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                            onSaved: (updated) => context.read<FixturesPollingNotifier>().updateFixture(updated),
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
                ],
              ),
            ),
    );
  }
}

