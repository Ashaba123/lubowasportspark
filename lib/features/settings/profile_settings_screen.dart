import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../features/league/league_repository.dart';
import '../../features/league/login_screen.dart';
import '../../features/league/models/league.dart';
import '../../features/league/public_league_view_screen.dart';
import '../../shared/page_transitions.dart';

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
  static const String _avatarPathKey = 'avatar_path';
  static const String _cachedMePlayerKey = 'cached_me_player';
  static const String _cachedLeagueRolesKey = 'cached_league_roles';

  bool _hasToken = false;
  String? _username;
  String? _leagueUserSummary;
  MePlayer? _mePlayer;
  LeagueRoles? _roles;
  bool _loading = true;
  File? _avatarFile;
  final ImagePicker _imagePicker = ImagePicker();
  bool _authCheckInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadCachedLeagueData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPathKey);
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) {
      await prefs.remove(_avatarPathKey);
      return;
    }
    if (!mounted) return;
    setState(() {
      _avatarFile = file;
    });
  }

  Future<void> _saveLeagueDataToCache(LeagueRoles roles, MePlayer? player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedLeagueRolesKey, jsonEncode(roles.toJson()));
    if (player != null) {
      await prefs.setString(_cachedMePlayerKey, jsonEncode(player.toJson()));
    } else {
      await prefs.remove(_cachedMePlayerKey);
    }
  }

  String _buildLeagueUserSummary(LeagueRoles roles, MePlayer? player) {
    final buf = StringBuffer();
    if (roles.canCreateLeague) buf.write('League creator. ');
    if (roles.managedLeagueIds.isNotEmpty) buf.write('Manages ${roles.managedLeagueIds.length} league(s). ');
    if (roles.ledTeamIds.isNotEmpty) buf.write('Leads ${roles.ledTeamIds.length} team(s). ');
    if (player != null) buf.write('Career goals: ${player.goals}.');
    return buf.isEmpty ? 'Logged in for leagues.' : buf.toString().trim();
  }

  Future<void> _loadCachedLeagueData() async {
    final prefs = await SharedPreferences.getInstance();
    final rolesJson = prefs.getString(_cachedLeagueRolesKey);
    final playerJson = prefs.getString(_cachedMePlayerKey);
    if (rolesJson == null && playerJson == null) {
      return;
    }
    LeagueRoles? roles;
    MePlayer? player;
    try {
      if (rolesJson != null) {
        roles = LeagueRoles.fromJson(jsonDecode(rolesJson) as Map<String, dynamic>);
      }
      if (playerJson != null) {
        player = MePlayer.fromJson(jsonDecode(playerJson) as Map<String, dynamic>);
      }
    } catch (_) {
      // Ignore cache decoding issues; will be replaced by fresh data.
    }
    if (!mounted) return;
    if (roles == null && player == null) {
      return;
    }
    final summary = roles != null ? _buildLeagueUserSummary(roles, player) : null;
    setState(() {
      _roles = roles ?? _roles;
      _mePlayer = player ?? _mePlayer;
      _leagueUserSummary = summary ?? _leagueUserSummary;
      _loading = false;
    });
  }

  Future<void> _checkAuth() async {
    if (_authCheckInProgress) return;
    _authCheckInProgress = true;
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
        _roles = null;
        _loading = false;
      });
      _authCheckInProgress = false;
      return;
    }
    setState(() => _username = _usernameFromToken(token));
    try {
      final repo = LeagueRepository(apiClient: context.read<ApiClient>());
      final roles = await repo.getMyLeagueRoles(forceRefresh: true);
      final player = await repo.getMyPlayer(forceRefresh: true);
      if (!mounted) return;
      await _saveLeagueDataToCache(roles, player);
      final summary = _buildLeagueUserSummary(roles, player);
      setState(() {
        _hasToken = true;
        _leagueUserSummary = summary;
        _mePlayer = player;
        _roles = roles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasToken = true;
        _leagueUserSummary = 'Logged in for leagues.';
        _mePlayer = null;
        _roles = null;
        _loading = false;
      });
    } finally {
      _authCheckInProgress = false;
    }
  }

  Future<void> _logout() async {
    final tokenStorage = context.read<TokenStorage>();
    await tokenStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
    await prefs.remove(_cachedMePlayerKey);
    await prefs.remove(_cachedLeagueRolesKey);
    if (!mounted) return;
    setState(() {
      _hasToken = false;
      _username = null;
      _leagueUserSummary = null;
      _mePlayer = null;
      _roles = null;
      _avatarFile = null;
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final avatarPath = '${docsDir.path}${Platform.pathSeparator}user_avatar.jpg';
      final sourceFile = File(picked.path);
      final copied = await sourceFile.copy(avatarPath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPathKey, copied.path);
      setState(() {
        _avatarFile = copied;
      });
    } catch (_) {
      // Ignore failures; keep existing avatar/initials.
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted && result == true) _checkAuth();
  }

  void _openPublicLeagues() {
    Navigator.of(context).push(
      fadeSlideRoute(builder: (_) => const PublicLeagueViewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hasToken
                      ? _ProfileHeader(
                          username: _username,
                          mePlayer: _mePlayer,
                          roles: _roles,
                          avatarFile: _avatarFile,
                          onEditAvatar: _pickAvatar,
                        )
                      : _LoggedOutHeader(onViewLeagues: _openPublicLeagues),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    hasToken: _hasToken,
                    leagueUserSummary: _leagueUserSummary,
                    onLogin: _openLogin,
                    onLogout: _logout,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.username,
    required this.mePlayer,
    required this.roles,
    required this.avatarFile,
    required this.onEditAvatar,
  });

  final String? username;
  final MePlayer? mePlayer;
  final LeagueRoles? roles;
  final File? avatarFile;
  final VoidCallback onEditAvatar;

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName =
        ((mePlayer != null && mePlayer!.name.isNotEmpty) ? mePlayer!.name : null) ?? username ?? 'Player';
    final goals = mePlayer?.goals ?? 0;
    final leagues = roles?.managedLeagueIds.length ?? 0;
    final teams = roles?.ledTeamIds.length ?? 0;
    final ImageProvider<Object>? avatarImage =
        avatarFile != null ? FileImage(avatarFile!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 96,
                backgroundColor: cs.primaryContainer,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        _initialsFromName(displayName),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEditAvatar,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, size: 16, color: cs.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'League profile',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
        color: cs.surface.withValues(alpha: 0.98),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                _ProfileStat(label: 'Goals', value: goals.toString(), icon: Icons.sports_soccer),
                const SizedBox(width: 8),
                _ProfileStat(label: 'Leagues', value: leagues.toString(), icon: Icons.emoji_events_outlined),
                const SizedBox(width: 8),
                _ProfileStat(label: 'Teams', value: teams.toString(), icon: Icons.groups_2_outlined),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedOutHeader extends StatelessWidget {
  const _LoggedOutHeader({required this.onViewLeagues});

  final VoidCallback onViewLeagues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      color: cs.surface.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.person_outline, color: cs.onPrimaryContainer, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public leagues & tables',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View league tables and results without logging in.',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onViewLeagues,
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('View leagues & tables'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.hasToken,
    required this.leagueUserSummary,
    required this.onLogin,
    required this.onLogout,
  });

  final bool hasToken;
  final String? leagueUserSummary;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      color: cs.surface.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Account',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasToken) ...[
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('League account'),
                subtitle: leagueUserSummary != null
                    ? Text(
                        leagueUserSummary!,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: onLogout,
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Log in'),
                subtitle: Text(
                  'Sign in to manage your leagues and bookings.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                onTap: onLogin,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
