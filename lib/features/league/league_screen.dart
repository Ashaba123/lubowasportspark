import 'package:flutter/material.dart';

import '../../core/api/app_api_provider.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
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
  PublicLeagueResponse? _publicData;
  LeagueRoles? _leagueRoles;
  MePlayer? _mePlayer;
  bool _loadingRoles = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadManageContent() async {
    setState(() => _loadingRoles = true);
    try {
      final roles = await _repository.getMyLeagueRoles();
      MePlayer? player;
      try {
        player = await _repository.getMyPlayer();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _leagueRoles = roles;
        _mePlayer = player;
        _loadingRoles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoles = false);
    }
  }

  void _logout() {
    AppApiProvider.tokenStorageOf(context).clear();
    setState(() {
      _leagueRoles = null;
      _mePlayer = null;
    });
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
      _publicData = null;
    });
    try {
      final data = await _repository.getPublicLeague(code);
      if (!mounted) return;
      setState(() {
        _publicData = data;
        _loading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('League')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('View by code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      hintText: 'League code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _loadByCode(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _loadByCode,
                  child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('View'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              SelectableText(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
            if (_publicData != null) ...[
              const SizedBox(height: 16),
              _PublicLeagueContent(data: _publicData!),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text('Manage leagues', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_leagueRoles != null)
              _ManageSection(
                leagueRoles: _leagueRoles!,
                mePlayer: _mePlayer,
                repository: _repository,
                onLogout: _logout,
                onRefresh: _loadManageContent,
              )
            else
              OutlinedButton.icon(
                onPressed: _loadingRoles
                    ? null
                    : () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                        if (ok == true && mounted) _loadManageContent();
                      },
                icon: _loadingRoles ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                label: const Text('Log in to create and manage leagues'),
              ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(data.league.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.standings.isNotEmpty) ...[
          Text('Standings', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(0.6), 2: FlexColumnWidth(0.6), 3: FlexColumnWidth(0.6), 4: FlexColumnWidth(0.6)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('Team', style: TextStyle(fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(6), child: Text('P', style: TextStyle(fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(6), child: Text('W', style: TextStyle(fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(6), child: Text('D', style: TextStyle(fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.all(6), child: Text('L', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
              ...data.standings.map((row) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(row.teamName, overflow: TextOverflow.ellipsis)),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${row.points}')),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${row.won}')),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${row.drawn}')),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${row.lost}')),
                ],
              )),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (data.fixtures.isNotEmpty) ...[
          Text('Fixtures', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          ...data.fixtures.take(20).map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(f.homeTeamName ?? 'Team ${f.homeTeamId}', overflow: TextOverflow.ellipsis)),
                Text(' ${f.homeGoals ?? 0} - ${f.awayGoals ?? 0} ', style: theme.textTheme.bodySmall),
                Expanded(child: Text(f.awayTeamName ?? 'Team ${f.awayTeamId}', overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
              ],
            ),
          )),
          if (data.fixtures.length > 20) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+ ${data.fixtures.length - 20} more', style: theme.textTheme.bodySmall)),
          const SizedBox(height: 12),
        ],
        if (data.topScorers.isNotEmpty) ...[
          Text('Top scorers', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          ...data.topScorers.take(10).map((s) => ListTile(
            dense: true,
            title: Text(s.playerName),
            trailing: Text('${s.goals} goals'),
          )),
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
    required this.onLogout,
    required this.onRefresh,
  });

  final LeagueRoles leagueRoles;
  final MePlayer? mePlayer;
  final LeagueRepository repository;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leagueRoles.canCreateLeague)
          FilledButton.icon(
            onPressed: () => _showCreateLeagueDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create league'),
          ),
        if (leagueRoles.managedLeagueIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('Leagues I manage'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _LeagueListScreen(repository: repository, filterManaged: true, managedIds: leagueRoles.managedLeagueIds)),
            ),
          ),
        ],
        if (leagueRoles.ledTeamIds.isNotEmpty) ...[
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Teams I lead'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _LeagueListScreen(repository: repository, filterManaged: false, ledTeamIds: leagueRoles.ledTeamIds)),
            ),
          ),
        ],
        if (mePlayer != null)
          ListTile(
            leading: const Icon(Icons.star),
            title: Text('My career goals: ${mePlayer!.goals}'),
            subtitle: Text(mePlayer!.teamName ?? ''),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('My leagues')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: Text(widget.filterManaged ? 'Leagues I manage' : 'Teams I lead')),
      body: ListView.builder(
        itemCount: _leagues.length,
        itemBuilder: (_, i) {
          final l = _leagues[i];
          return ListTile(
            title: Text(l.name),
            subtitle: Text('Code: ${l.code}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _LeagueDetailScreen(league: l, repository: widget.repository)),
            ),
          );
        },
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
    if (_loading) return Scaffold(appBar: AppBar(title: Text(widget.league.name)), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.league.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Code: ${widget.league.code}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Teams (${_teams.length})', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddTeam(context),
                icon: const Icon(Icons.add),
                label: const Text('Add team'),
              ),
            ],
          ),
          ..._teams.map((t) => ListTile(title: Text(t.name), onTap: () => _openTeam(context, t))),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Fixtures', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.repository.generateFixtures(widget.league.id);
                    if (mounted) _load();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
                child: const Text('Generate'),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.repository.resetFixtures(widget.league.id);
                    if (mounted) _load();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          ..._fixtures.map((f) => ListTile(
                title: Text('${f.homeTeamName ?? "?"} vs ${f.awayTeamName ?? "?"}'),
                subtitle: Text('${f.homeGoals ?? 0} - ${f.awayGoals ?? 0}${f.isFullTime ? " (FT)" : ""}'),
                onTap: () => _openFixture(context, f),
              )),
        ],
      ),
    );
  }

  void _openTeam(BuildContext context, TeamModel team) {
    Navigator.of(context).push(
      MaterialPageRoute(
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
      if (mounted) _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openFixture(BuildContext context, FixtureModel fixture) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FixtureEditScreen(fixture: fixture, repository: widget.repository, onSaved: _load),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: Text(widget.team.name)), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Players (${_players.length}/8)', style: Theme.of(context).textTheme.titleSmall),
          ..._players.map((p) => ListTile(title: Text(p.name), trailing: Text('${p.goals} goals'))),
          if (_players.length < 8)
            TextButton.icon(
              onPressed: () => _showAddPlayer(context),
              icon: const Icon(Icons.add),
              label: const Text('Add player'),
            ),
        ],
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
      if (mounted) _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit fixture')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.fixture.homeTeamName ?? "Home"} vs ${widget.fixture.awayTeamName ?? "Away"}', style: Theme.of(context).textTheme.titleLarge),
            if (widget.fixture.isFullTime)
              const Padding(padding: EdgeInsets.only(top: 8), child: Text('Full time — score locked')),
            if (!widget.fixture.isFullTime) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _homeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Home goals'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _awayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Away goals'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _saving ? null : _save, child: const Text('Save score')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _saving ? null : _markFullTime, child: const Text('Mark full time')),
            ],
          ],
        ),
      ),
    );
  }
}
