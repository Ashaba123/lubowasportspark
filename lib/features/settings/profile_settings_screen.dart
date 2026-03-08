import 'package:flutter/material.dart';

import '../../core/api/app_api_provider.dart';
import '../../features/league/league_repository.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _hasToken = false;
  String? _leagueUserSummary;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final tokenStorage = AppApiProvider.tokenStorageOf(context);
    final token = await tokenStorage.getToken();
    if (!mounted) return;
    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      setState(() {
        _hasToken = false;
        _leagueUserSummary = null;
        _loading = false;
      });
      return;
    }
    try {
      final repo = LeagueRepository(apiClient: AppApiProvider.apiClientOf(context));
      final roles = await repo.getMyLeagueRoles();
      final player = await repo.getMyPlayer();
      if (!mounted) return;
      final buf = StringBuffer();
      if (roles.canCreateLeague) buf.write('League creator. ');
      if (roles.managedLeagueIds.isNotEmpty) buf.write('Manages ${roles.managedLeagueIds.length} league(s). ');
      if (roles.ledTeamIds.isNotEmpty) buf.write('Leads ${roles.ledTeamIds.length} team(s). ');
      if (player != null) buf.write('Career goals: ${player.goals}.');
      setState(() {
        _hasToken = true;
        _leagueUserSummary = buf.isEmpty ? 'Logged in for leagues.' : buf.toString().trim();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasToken = true;
        _leagueUserSummary = 'Logged in for leagues.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final tokenStorage = AppApiProvider.tokenStorageOf(context);
    await tokenStorage.clear();
    if (!mounted) return;
    setState(() {
      _hasToken = false;
      _leagueUserSummary = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (!_loading) ...[
              Text(
                'Profile',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_hasToken) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leagues account',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_leagueUserSummary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _leagueUserSummary!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Log out'),
                          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Profile settings will let you manage your basic details used for bookings and leagues.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'What you will be able to do here:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(
              text:
                  'Update your name and contact details used when you request bookings or join leagues.',
            ),
            _Bullet(
              text:
                  'Link your account to a player profile so your goals and league stats can be tracked.',
            ),
            _Bullet(
              text:
                  'Review how your information is used across bookings, leagues, and other services.',
            ),
            const SizedBox(height: 16),
            Text(
              'For now, profile changes can be handled directly with the Lubowa Sports Park team.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

