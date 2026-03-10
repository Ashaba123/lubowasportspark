import 'package:flutter/material.dart';

import 'models/league.dart';
import 'public_league_content.dart';

/// Public league view for non-logged-in users.
class PublicLeagueScreen extends StatelessWidget {
  const PublicLeagueScreen({super.key, required this.data});

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
          const SizedBox(height: 24),
          PublicLeagueContent(data: data),
        ],
      ),
    );
  }
}

