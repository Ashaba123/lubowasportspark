import 'package:flutter/material.dart';

import 'models/league.dart';
import 'stat_chip.dart';
import 'league_repository.dart';

/// Single player view: name, team, league, goals.
class PlayerViewScreen extends StatefulWidget {
  const PlayerViewScreen({
    super.key,
    required this.player,
    required this.teamName,
    required this.leagueName,
    required this.repository,
  });

  final PlayerModel player;
  final String teamName;
  final String leagueName;
  final LeagueRepository repository;

  @override
  State<PlayerViewScreen> createState() => _PlayerViewScreenState();
}

class _PlayerViewScreenState extends State<PlayerViewScreen> {
  late int _goals;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _goals = widget.player.goals;
  }

  Future<void> _showAddGoalsDialog() async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add goals'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of goals to add',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final toAdd = int.tryParse(ctrl.text.trim());
    if (toAdd == null || toAdd <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Enter a positive number of goals.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
      );
      return;
    }

    final newTotal = _goals + toAdd;

    setState(() => _updating = true);
    try {
      await widget.repository.updatePlayer(widget.player.id, goals: newTotal);
      if (!mounted) return;
      setState(() => _goals = newTotal);
      messenger.showSnackBar(
        SnackBar(content: Text('Updated goals to $newTotal')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.player.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _updating ? null : _showAddGoalsDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add goals'),
      ),
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
                      '$_goals',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.player.name, style: theme.textTheme.titleLarge),
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
                  subtitle: Text(widget.teamName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.emoji_events_outlined, color: colorScheme.primary),
                  title: const Text('League'),
                  subtitle: Text(widget.leagueName),
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
                    value: '$_goals',
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

