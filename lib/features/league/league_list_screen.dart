import 'package:flutter/material.dart';

import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_detail_screen.dart';
import 'league_repository.dart';
import 'models/league.dart';

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
  List<LeagueModel> _leagues = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getLeagues(forceRefresh: true);
      if (!mounted) return;
      final filtered = widget.filterManaged
          ? list.where((l) => widget.managedIds.contains(l.id)).toList()
          : list;
      setState(() {
        _leagues = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.filterManaged ? 'Leagues I manage' : 'Teams I lead';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: FootballLoader()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _leagues.isEmpty
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
                itemCount: _leagues.length,
                itemBuilder: (_, i) {
                  final l = _leagues[i];
                  return Card(
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
                                  Text('Code: ${l.code}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
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

