import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/features/league/models/league.dart';
import 'package:lubowa_sports_park/features/league/stat_chip.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';

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
  late String _playerName;
  bool _updating = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _goals = widget.player.goals;
    _playerName = widget.player.name;
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
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary),
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
      setState(() {
        _goals = newTotal;
        _changed = true;
      });
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

  Future<void> _renamePlayer() async {
    final nameCtrl = TextEditingController(text: _playerName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename player'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Player name'),
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
    if (ok != true) return;
    setState(() => _updating = true);
    try {
      final updated = await widget.repository.updatePlayer(
        widget.player.id,
        name: nameCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _playerName = updated.name;
        _changed = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _deletePlayer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete player'),
        content: const Text(
            'Are you sure you want to delete this player? This cannot be undone.'),
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
    if (ok != true) return;
    setState(() => _updating = true);
    try {
      await widget.repository.deletePlayer(widget.player.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player deleted')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _resetGoals() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset goals'),
        content: const Text('Set this player\'s goals back to 0?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _updating = true);
    try {
      final updated =
          await widget.repository.updatePlayer(widget.player.id, goals: 0);
      if (!mounted) return;
      setState(() {
        _goals = updated.goals;
        _changed = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goals reset')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, Object? result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop<bool>(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_playerName),
          actions: [
            IconButton(
              tooltip: 'Rename player',
              icon: const Icon(Icons.edit),
              onPressed: _updating ? null : _renamePlayer,
            ),
            IconButton(
              tooltip: 'Delete player',
              icon: const Icon(Icons.delete_outline),
              onPressed: _updating ? null : _deletePlayer,
            ),
          ],
        ),
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
                    Text(_playerName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Goals',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                    leading:
                        Icon(Icons.groups_outlined, color: colorScheme.primary),
                    title: const Text('Team'),
                    subtitle: Text(widget.teamName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.emoji_events_outlined,
                        color: colorScheme.primary),
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
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _updating ? null : _resetGoals,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset goals'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
