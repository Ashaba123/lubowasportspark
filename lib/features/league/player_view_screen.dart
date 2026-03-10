import 'package:flutter/material.dart';

import 'models/league.dart';
import 'stat_chip.dart';

/// Single player view: name, team, league, goals.
class PlayerViewScreen extends StatelessWidget {
  const PlayerViewScreen({
    super.key,
    required this.player,
    required this.teamName,
    required this.leagueName,
  });

  final PlayerModel player;
  final String teamName;
  final String leagueName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${player.goals}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(player.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Goals',
                    style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.groups_outlined, color: colorScheme.primary),
                  title: const Text('Team'),
                  subtitle: Text(teamName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.emoji_events_outlined, color: colorScheme.primary),
                  title: const Text('League'),
                  subtitle: Text(leagueName),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StatChip(
                    value: '${player.goals}',
                    label: 'Goals',
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

