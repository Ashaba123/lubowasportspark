import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../features/league/league_repository.dart';
import '../../features/league/login_screen.dart';
import '../../features/league/models/league.dart';

/// Tries to decode JWT payload and return a display name (user_nicename, display_name, or username).
String? _usernameFromToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    final map = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>?;
    if (map == null) return null;
    final data = map['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>? ?? data ?? map;
    return (user['user_nicename'] as String?) ??
        (user['display_name'] as String?) ??
        (user['username'] as String?) ??
        (map['user_nicename'] as String?) ??
        (map['username'] as String?);
  } catch (_) {
    return null;
  }
}

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _hasToken = false;
  String? _username;
  String? _leagueUserSummary;
  MePlayer? _mePlayer;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final tokenStorage = context.read<TokenStorage>();
    final token = await tokenStorage.getToken();
    if (!mounted) return;
    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      setState(() {
        _hasToken = false;
        _username = null;
        _leagueUserSummary = null;
        _mePlayer = null;
        _loading = false;
      });
      return;
    }
    setState(() => _username = _usernameFromToken(token));
    try {
      final repo = LeagueRepository(apiClient: context.read<ApiClient>());
      final roles = await repo.getMyLeagueRoles(forceRefresh: true);
      final player = await repo.getMyPlayer(forceRefresh: true);
      if (!mounted) return;
      final buf = StringBuffer();
      if (roles.canCreateLeague) buf.write('League creator. ');
      if (roles.managedLeagueIds.isNotEmpty) buf.write('Manages ${roles.managedLeagueIds.length} league(s). ');
      if (roles.ledTeamIds.isNotEmpty) buf.write('Leads ${roles.ledTeamIds.length} team(s). ');
      if (player != null) buf.write('Career goals: ${player.goals}.');
      setState(() {
        _hasToken = true;
        _leagueUserSummary = buf.isEmpty ? 'Logged in for leagues.' : buf.toString().trim();
        _mePlayer = player;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasToken = true;
        _leagueUserSummary = 'Logged in for leagues.';
        _mePlayer = null;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final tokenStorage = context.read<TokenStorage>();
    await tokenStorage.clear();
    if (!mounted) return;
    setState(() {
      _hasToken = false;
      _username = null;
      _leagueUserSummary = null;
      _mePlayer = null;
    });
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted && result == true) _checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _hasToken
                ? _buildLoggedIn(theme, cs)
                : _buildLoggedOut(theme, cs),
      ),
    );
  }

  Widget _buildLoggedOut(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.person_outline, size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Log in to manage leagues and link your player profile.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Log in'),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedIn(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_username != null && _username!.isNotEmpty) ...[
                  Text('Logged in as', style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_username!, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                ],
                if (_mePlayer != null) ...[
                  _InfoRow(label: 'Player', value: _mePlayer!.name),
                  if (_mePlayer!.teamName != null && _mePlayer!.teamName!.isNotEmpty)
                    _InfoRow(label: 'Team', value: _mePlayer!.teamName!),
                  if (_mePlayer!.leagueName != null && _mePlayer!.leagueName!.isNotEmpty)
                    _InfoRow(label: 'League', value: _mePlayer!.leagueName!),
                  _InfoRow(label: 'Career goals', value: '${_mePlayer!.goals}'),
                  const SizedBox(height: 16),
                ],
                if (_leagueUserSummary != null && _leagueUserSummary!.isNotEmpty) ...[
                  Text(
                    _leagueUserSummary!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                ],
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
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
