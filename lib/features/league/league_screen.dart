import 'package:flutter/material.dart';

import '../../core/api/app_api_provider.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../shared/page_transitions.dart';
import '../../shared/football_loader.dart';
import 'models/league.dart';
import 'league_repository.dart';
import 'login_screen.dart';

/// League: public (enter code → standings/results) and manage (login → create league, my leagues, my teams).
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late final LeagueRepository _repository = LeagueRepository(apiClient: AppApiProvider.apiClientOf(context));
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a league code.');
      return;
    }
    if (!await hasNetworkConnectivity()) {
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final data = await _repository.getPublicLeague(code);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        fadeSlideRoute(builder: (_) => PublicLeagueScreen(data: data)),
      );
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${userFriendlyApiErrorMessage(e)}\n\nRaw (share if needed): $e\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Leagues')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Public league stats',
                      style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a league code to see standings, fixtures, and top scorers. No login needed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              hintText: 'League code (e.g. L755V9)',
                              filled: true,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _loadByCode(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: _loading ? null : _loadByCode,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, 48),
                            foregroundColor: colorScheme.primary,
                            backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
                          ),
                          child: _loading
                              ? const FootballLoader(size: 22)
                              : const Text('View'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_circle, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Login to manage a league', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Ask the Lubowa Sports Park staff to create a login for you. '
                                'Use that account to create leagues, add teams and players, and generate fixtures.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final tokenStorage = AppApiProvider.tokenStorageOf(context);
                        final token = await tokenStorage.getToken();
                        if (mounted && token != null && token.isNotEmpty) {
                          await navigator.push(
                            fadeSlideRoute(
                              builder: (_) => LeagueManageScreen(repository: _repository),
                            ),
                          );
                          return;
                        }
                        final ok = await navigator.push<bool>(
                          fadeSlideRoute(builder: (_) => const LoginScreen()),
                        );
                        if (ok == true && mounted) {
                          await navigator.push(
                            fadeSlideRoute(
                              builder: (_) => LeagueManageScreen(repository: _repository),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Manage leagues'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final roles = await widget.repository.getMyLeagueRoles();
      MePlayer? player;
      try {
        player = await widget.repository.getMyPlayer();
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.emoji_events, color: colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Manage your leagues', style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Create leagues, add teams and players, generate fixtures, and record scores.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_leagueRoles != null)
                    _ManageSection(
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
          _PublicLeagueContent(data: data),
        ],
      ),
    );
  }
}

class _PublicLeagueContent extends StatelessWidget {
  const _PublicLeagueContent({required this.data});

  final PublicLeagueResponse data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.standings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Standings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(28),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(0.6),
                      3: FlexColumnWidth(0.6),
                      4: FlexColumnWidth(0.6),
                      5: FlexColumnWidth(0.6),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
                        children: [
                          const Padding(padding: EdgeInsets.all(8), child: SizedBox.shrink()),
                          Padding(padding: const EdgeInsets.all(8), child: Text('Team', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('P', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('W', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('D', style: theme.textTheme.labelLarge)),
                          Padding(padding: const EdgeInsets.all(8), child: Text('L', style: theme.textTheme.labelLarge)),
                        ],
                      ),
                      ...data.standings.asMap().entries.map((entry) {
                        final rank = entry.key;
                        final row = entry.value;
                        final rankColor = switch (rank) {
                          0 => const Color(0xFFFFD700),
                          1 => const Color(0xFFC0C0C0),
                          2 => const Color(0xFFCD7F32),
                          _ => null,
                        };
                        final rowBg = rank < 3 ? rankColor?.withValues(alpha: 0.08) : null;
                        return TableRow(
                          decoration: rowBg != null ? BoxDecoration(color: rowBg) : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: rankColor != null
                                  ? Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
                                    )
                                  : Text('${rank + 1}', style: theme.textTheme.bodySmall),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(row.teamName, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                            ),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.points}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.won}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.drawn}', style: theme.textTheme.bodyMedium)),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${row.lost}', style: theme.textTheme.bodyMedium)),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (data.fixtures.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Fixtures', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.fixtures.take(20).map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.homeTeamName ?? 'Team ${f.homeTeamId}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          ' ${f.homeGoals ?? 0} - ${f.awayGoals ?? 0} ',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        Expanded(
                          child: Text(
                            f.awayTeamName ?? 'Team ${f.awayTeamId}',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (data.fixtures.length > 20)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('+ ${data.fixtures.length - 20} more', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (data.topScorers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Top scorers', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...data.topScorers.take(10).map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.playerName, style: theme.textTheme.bodyMedium),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${s.goals} goals', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ManageSection extends StatelessWidget {
  const _ManageSection({
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
        if (leagueRoles.canCreateLeague)
          FilledButton.icon(
            onPressed: () => _showCreateLeagueDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create league'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        if (leagueRoles.managedLeagueIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => _LeagueListScreen(repository: repository, filterManaged: true, managedIds: leagueRoles.managedLeagueIds)),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
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
                          Text('Open to add teams, players, and fixtures', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
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
        if (leagueRoles.ledTeamIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => _LeagueListScreen(repository: repository, filterManaged: false, ledTeamIds: leagueRoles.ledTeamIds)),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withValues(alpha: 0.15),
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
                          Text('Manage players and record goals', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
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
          const SizedBox(height: 8),
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
                children: [1, 2, 3].map((n) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: legs == n,
                    onSelected: (_) => setDialogState(() => legs = n),
                  ),
                )).toList(),
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

class _LeagueListScreen extends StatefulWidget {
  const _LeagueListScreen({required this.repository, required this.filterManaged, this.managedIds = const [], this.ledTeamIds = const []});

  final LeagueRepository repository;
  final bool filterManaged;
  final List<int> managedIds;
  final List<int> ledTeamIds;

  @override
  State<_LeagueListScreen> createState() => _LeagueListScreenState();
}

class _LeagueListScreenState extends State<_LeagueListScreen> {
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
      final list = await widget.repository.getLeagues();
      if (!mounted) return;
      final filtered = widget.filterManaged
          ? list.where((l) => widget.managedIds.contains(l.id)).toList()
          : list; // Teams I lead: show leagues where user has a led team (we have led_team_ids, not league ids - so show all and let user tap to see teams)
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
                        fadeSlideRoute(builder: (_) => _LeagueDetailScreen(league: l, repository: widget.repository)),
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

class _LeagueDetailScreen extends StatefulWidget {
  const _LeagueDetailScreen({required this.league, required this.repository});

  final LeagueModel league;
  final LeagueRepository repository;

  @override
  State<_LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<_LeagueDetailScreen> {
  List<TeamModel> _teams = [];
  List<FixtureModel> _fixtures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final teams = await widget.repository.getTeams(widget.league.id);
      List<FixtureModel> fixtures = [];
      try {
        fixtures = await widget.repository.getFixtures(widget.league.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _fixtures = fixtures;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.league.name)),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.league.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.league.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Code: ${widget.league.code}', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Teams', style: theme.textTheme.titleLarge),
                const SizedBox(width: 8),
                Text('(${_teams.length})', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddTeam(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add team'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._teams.map((t) => ListTile(
                        leading: Icon(Icons.groups_outlined, color: colorScheme.primary),
                        title: Text(t.name, style: theme.textTheme.bodyLarge),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTeam(context, t),
                      )),
                  if (_teams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Add at least 2 teams to generate fixtures.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Fixtures', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You (league creator) or park staff can generate fixtures. Needs at least 2 teams.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                fadeSlideRoute(
                  builder: (_) => _FixturesScreen(
                    league: widget.league,
                    repository: widget.repository,
                    initialFixtures: _fixtures,
                  ),
                ),
              ).then((_) {
                if (mounted) _load();
              }),
              icon: const Icon(Icons.calendar_view_month),
              label: const Text('View fixtures'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }

  void _openTeam(BuildContext context, TeamModel team) {
    Navigator.of(context).push(
      fadeSlideRoute(
        builder: (_) => _TeamDetailScreen(league: widget.league, team: team, repository: widget.repository),
      ),
    );
  }

  Future<void> _showAddTeam(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add team'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Team name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.addTeam(widget.league.id, name: nameCtrl.text.trim());
      if (mounted) await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

}

class _FixturesScreen extends StatefulWidget {
  const _FixturesScreen({
    required this.league,
    required this.repository,
    this.initialFixtures = const [],
  });

  final LeagueModel league;
  final LeagueRepository repository;
  final List<FixtureModel> initialFixtures;

  @override
  State<_FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<_FixturesScreen> {
  late List<FixtureModel> _fixtures;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fixtures = List.from(widget.initialFixtures);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getFixtures(widget.league.id);
      if (!mounted) return;
      setState(() {
        _fixtures = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.league.name} — Fixtures')),
      backgroundColor: colorScheme.surface,
      body: _loading && _fixtures.isEmpty
          ? const Center(child: FootballLoader())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text('Generate fixtures', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.repository.generateFixtures(widget.league.id);
                            if (mounted) await _load();
                            if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Fixtures generated')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text(userFriendlyApiErrorMessage(e))));
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Generate'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.repository.resetFixtures(widget.league.id);
                            if (mounted) await _load();
                            if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Fixtures reset')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('$e')));
                          }
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Needs at least 2 teams. You (league creator) or park staff can generate.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (_fixtures.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No fixtures yet. Add teams in the league then tap Generate.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: _fixtures.map((f) => ListTile(
                              title: Text(
                                '${f.homeTeamName ?? "?"} vs ${f.awayTeamName ?? "?"}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              subtitle: Text('${f.homeGoals ?? 0} – ${f.awayGoals ?? 0}${f.isFullTime ? " (FT)" : ""}'),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: () {
                                Navigator.of(context).push(
                                  fadeSlideRoute(
                                    builder: (_) => _FixtureEditScreen(
                                      fixture: f,
                                      repository: widget.repository,
                                      onSaved: _load,
                                    ),
                                  ),
                                );
                              },
                            )).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TeamDetailScreen extends StatefulWidget {
  const _TeamDetailScreen({required this.league, required this.team, required this.repository});

  final LeagueModel league;
  final TeamModel team;
  final LeagueRepository repository;

  @override
  State<_TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<_TeamDetailScreen> {
  List<PlayerModel> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getTeamPlayers(widget.team.id);
      if (!mounted) return;
      setState(() {
        _players = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openPlayer(BuildContext context, PlayerModel player) {
    Navigator.of(context).push(
      fadeSlideRoute(
        builder: (_) => _PlayerViewScreen(
          player: player,
          teamName: widget.team.name,
          leagueName: widget.league.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.team.name)),
        body: const Center(child: FootballLoader()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups, color: colorScheme.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.team.name, style: theme.textTheme.titleLarge),
                          Text('${_players.length}/8 players', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Players', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._players.map((p) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text('${p.goals}', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                        ),
                        title: Text(p.name, style: theme.textTheme.bodyLarge),
                        subtitle: Text('${p.goals} goals', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPlayer(context, p),
                      )),
                ],
              ),
            ),
            if (_players.length < 8) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _showAddPlayer(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add player'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlayer(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.addPlayer(widget.team.id, name: nameCtrl.text.trim());
      if (mounted) await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Single player view: name, team, league, goals.
class _PlayerViewScreen extends StatelessWidget {
  const _PlayerViewScreen({
    required this.player,
    required this.teamName,
    required this.leagueName,
  });

  final PlayerModel player;
  final String teamName;
  final String leagueName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
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
                      '${player.goals}',
                      style: theme.textTheme.headlineMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(player.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Goals', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
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
                  subtitle: Text(teamName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.emoji_events_outlined, color: colorScheme.primary),
                  title: const Text('League'),
                  subtitle: Text(leagueName),
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
                  _StatChip(value: '${player.goals}', label: 'Goals', theme: theme, colorScheme: colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label, required this.theme, required this.colorScheme});

  final String value;
  final String label;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _FixtureEditScreen extends StatefulWidget {
  const _FixtureEditScreen({required this.fixture, required this.repository, required this.onSaved});

  final FixtureModel fixture;
  final LeagueRepository repository;
  final Future<void> Function() onSaved;

  @override
  State<_FixtureEditScreen> createState() => _FixtureEditScreenState();
}

class _FixtureEditScreenState extends State<_FixtureEditScreen> {
  late final TextEditingController _homeCtrl;
  late final TextEditingController _awayCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: '${widget.fixture.homeGoals ?? 0}');
    _awayCtrl = TextEditingController(text: '${widget.fixture.awayGoals ?? 0}');
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  int get _homeGoals => int.tryParse(_homeCtrl.text) ?? 0;
  int get _awayGoals => int.tryParse(_awayCtrl.text) ?? 0;

  Future<void> _save() async {
    if (widget.fixture.isFullTime) return;
    final h = _homeGoals;
    final a = _awayGoals;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.repository.updateFixture(widget.fixture.id, homeGoals: h, awayGoals: a);
      if (mounted) onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void onSaved() => widget.onSaved();

  Future<void> _markFullTime() async {
    if (widget.fixture.isFullTime) return;
    final h = _homeGoals;
    final a = _awayGoals;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.repository.updateFixture(widget.fixture.id, homeGoals: h, awayGoals: a, resultConfirmed: 1);
      if (mounted) onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit fixture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${widget.fixture.homeTeamName ?? "Home"} vs ${widget.fixture.awayTeamName ?? "Away"}',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.fixture.isFullTime) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Full time — score locked', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!widget.fixture.isFullTime) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _homeCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.fixture.homeTeamName ?? 'Home',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _awayCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.fixture.awayTeamName ?? 'Away',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: _saving ? const FootballLoader(size: 22) : const Text('Save score'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _markFullTime,
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: const Text('Mark full time'),
            ),
          ],
        ],
      ),
    );
  }
}
