import 'package:flutter/material.dart';

import '../../shared/page_transitions.dart';
import 'league_list_screen.dart';
import 'league_repository.dart';
import 'models/league.dart';

class ManageSection extends StatelessWidget {
  const ManageSection({
    super.key,
    required this.leagueRoles,
    required this.mePlayer,
    required this.repository,
    required this.onRefresh,
  });

  final LeagueRoles leagueRoles;
  final MePlayer? mePlayer;
  final LeagueRepository repository;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leagueRoles.ledTeamIds.isNotEmpty) ...[
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(
                  builder: (_) => LeagueListScreen(
                    repository: repository,
                    filterManaged: false,
                    ledTeamIds: leagueRoles.ledTeamIds,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.groups, color: colorScheme.secondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Teams I lead', style: theme.textTheme.titleMedium),
                          Text(
                            'Manage players and record goals',
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
          ),
          const SizedBox(height: 12),
        ],
        if (leagueRoles.canCreateLeague) ...[
          FilledButton.icon(
            onPressed: () => _showCreateLeagueDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create league'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (leagueRoles.managedLeagueIds.isNotEmpty) ...[
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(
                  builder: (_) => LeagueListScreen(
                    repository: repository,
                    filterManaged: true,
                    managedIds: leagueRoles.managedLeagueIds,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.emoji_events, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leagues I manage', style: theme.textTheme.titleMedium),
                          Text(
                            'Open to add teams, players, and fixtures',
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
          ),
        ],
        if (mePlayer != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.star, color: colorScheme.primary),
              title: Text('My career goals: ${mePlayer!.goals}', style: theme.textTheme.titleSmall),
              subtitle: Text(mePlayer!.teamName ?? ''),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showCreateLeagueDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    int legs = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create league'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'League name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text('Legs (fixtures per pair)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Row(
                children: [1, 2, 3]
                    .map(
                      (n) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$n'),
                          selected: legs == n,
                          onSelected: (_) => setDialogState(() => legs = n),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await repository.createLeague(name: name, legs: legs);
                  if (context.mounted) {
                    messenger.showSnackBar(const SnackBar(content: Text('League created')));
                    onRefresh();
                  }
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

