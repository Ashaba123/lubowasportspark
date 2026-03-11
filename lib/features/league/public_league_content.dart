import 'package:flutter/material.dart';

import '../../shared/football_loader.dart';
import 'models/league.dart';

class PublicLeagueContent extends StatelessWidget {
  const PublicLeagueContent({super.key, required this.data});

  final PublicLeagueResponse data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.standings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Standings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(28),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(0.6),
                      3: FlexColumnWidth(0.6),
                      4: FlexColumnWidth(0.6),
                      5: FlexColumnWidth(0.6),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
                        children: [
                          const Padding(padding: EdgeInsets.all(8), child: SizedBox.shrink()),
                          Padding(padding: const EdgeInsets.all(8), child: Text('Team', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('P', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('W', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('D', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('L', style: theme.textTheme.labelLarge)),
                        ],
                      ),
                      ...data.standings.asMap().entries.map((entry) {
                        final rank = entry.key;
                        final row = entry.value;
                        final rankColor = switch (rank) {
                          0 => const Color(0xFFFFD700),
                          1 => const Color(0xFFC0C0C0),
                          2 => const Color(0xFFCD7F32),
                          _ => null,
                        };
                        final rowBg = rank < 3 ? rankColor?.withValues(alpha: 0.08) : null;
                        return TableRow(
                          decoration: rowBg != null ? BoxDecoration(color: rowBg) : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: rankColor != null
                                  ? Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
                                    )
                                  : Text('${rank + 1}', style: theme.textTheme.bodySmall),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(row.teamName, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                            ),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.points}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.won}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.drawn}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.lost}', style: theme.textTheme.bodyMedium)),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (data.fixtures.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Fixtures', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.fixtures.take(20).map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.homeTeamName ?? 'Team ${f.homeTeamId}',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                ' ${f.homeGoals ?? 0} - ${f.awayGoals ?? 0} ',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                              Expanded(
                                child: Text(
                                  f.awayTeamName ?? 'Team ${f.awayTeamId}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (data.fixtures.length > 20)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('+ ${data.fixtures.length - 20} more', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (data.topScorers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Top scorers', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.topScorers.take(10).map(
                        (s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 20, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(s.playerName, style: theme.textTheme.bodyMedium),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${s.goals} goals',
                                  style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
        if (data.standings.isEmpty && data.fixtures.isEmpty && data.topScorers.isEmpty) ...[
          const SizedBox(height: 32),
          const Center(child: FootballLoader()),
        ],
      ],
    );
  }
}

