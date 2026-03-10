import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'league_repository.dart';
import 'models/league.dart';
import 'public_league_content.dart';

/// Public league view for non-logged-in users.
class PublicLeagueScreen extends StatelessWidget {
  const PublicLeagueScreen({
    super.key,
    required this.data,
    this.repository,
  });

  final PublicLeagueResponse data;
  final LeagueRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    if (repo == null) {
      // Fallback to static snapshot if repository isn't provided.
      return _PublicLeagueScaffold(data: data);
    }
    return Provider<LeagueRepository>.value(
      value: repo,
      child: StreamProvider<PublicLeagueResponse>.value(
        initialData: data,
        value: repo.getPublicLeagueStream(data.league.code),
        child: _PublicLeagueStreamBody(initial: data),
      ),
    );
  }
}

class _PublicLeagueStreamBody extends StatelessWidget {
  const _PublicLeagueStreamBody({required this.initial});

  final PublicLeagueResponse initial;

  @override
  Widget build(BuildContext context) {
    final latest = context.watch<PublicLeagueResponse>();
    return _PublicLeagueScaffold(data: latest);
  }
}

class _PublicLeagueScaffold extends StatelessWidget {
  const _PublicLeagueScaffold({required this.data});

  final PublicLeagueResponse data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(data.league.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock_open, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${data.league.code}', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Public view — no login required.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.sports_soccer, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Live — updates every few seconds',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PublicLeagueContent(data: data),
        ],
      ),
    );
  }
}

