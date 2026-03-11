import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/manage_section.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

/// Manage leagues and teams after logging in.
class LeagueManageScreen extends StatefulWidget {
  const LeagueManageScreen({super.key, required this.repository});

  final LeagueRepository repository;

  @override
  State<LeagueManageScreen> createState() => _LeagueManageScreenState();
}

class _LeagueManageScreenState extends State<LeagueManageScreen> {
  LeagueRoles? _leagueRoles;
  MePlayer? _mePlayer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadManageContent();
  }

  Future<void> _loadManageContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await widget.repository.getMyLeagueRoles(forceRefresh: true);
      MePlayer? player;
      try {
        player = await widget.repository.getMyPlayer(forceRefresh: true);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _leagueRoles = roles;
        _mePlayer = player;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage leagues')),
      backgroundColor: colorScheme.surface,
      body: _loading
          ? const Center(child: FootballLoader())
          : RefreshIndicator(
              onRefresh: _loadManageContent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Manage your leagues',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create leagues, add teams and players, generate fixtures, and record scores.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_leagueRoles != null)
                    ManageSection(
                      leagueRoles: _leagueRoles!,
                      mePlayer: _mePlayer,
                      repository: widget.repository,
                      onRefresh: _loadManageContent,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Your session has expired. Go back to the Leagues tab and log in again.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

