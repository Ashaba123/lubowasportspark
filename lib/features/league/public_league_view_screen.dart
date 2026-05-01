import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';
import 'package:lubowa_sports_park/features/league/public_league_screen.dart';

/// Dedicated screen for public view of leagues: enter code → preview → view standings, results, top scorers.
/// Used when a guest taps "View leagues & tables" in profile.
class PublicLeagueViewScreen extends StatefulWidget {
  const PublicLeagueViewScreen({super.key});

  @override
  State<PublicLeagueViewScreen> createState() => _PublicLeagueViewScreenState();
}

class _PublicLeagueViewScreenState extends State<PublicLeagueViewScreen> {
  late final LeagueRepository _repository =
      LeagueRepository(apiClient: context.read<ApiClient>());
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  PublicLeagueResponse? _preview;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the league code shared by your organizer.');
      return;
    }
    if (!await hasNetworkConnectivity()) {
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
      _preview = null;
    });
    try {
      final data = await _repository.getPublicLeague(code, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _preview = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  void _openLeague() {
    final data = _preview;
    if (data == null) return;
    Navigator.of(context).push(
      fadeSlideRoute(
        builder: (_) => PublicLeagueScreen(data: data, repository: _repository),
      ),
    );
  }

  void _contactOrganizer() {
    launchUrl(
      Uri.parse('https://wa.me/256781773771'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Leagues & tables')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View league stats', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the code shared by your league organizer to see standings, fixtures, and top scorers. No login needed.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              hintText: 'League code (e.g. L755V9)',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _loadByCode(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _loading ? null : _loadByCode,
                          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
                          child: _loading
                              ? const FootballLoader(size: 22)
                              : const Text('View'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              _LeaguePreviewCard(
                data: _preview!,
                onConfirm: _openLeague,
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _contactOrganizer,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Contact the organizer'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Don't have a code? Ask your league organizer or the Lubowa Sports Park staff.",
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaguePreviewCard extends StatelessWidget {
  const _LeaguePreviewCard({required this.data, required this.onConfirm});

  final PublicLeagueResponse data;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final league = data.league;
    final teamCount = data.standings.length;
    final fixtureCount = data.fixtures.length;

    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.emoji_events_outlined, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        league.name.isEmpty ? 'League' : league.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Futsal · ${league.legs} ${league.legs == 1 ? 'leg' : 'legs'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PreviewChip(icon: Icons.groups_2_outlined, label: '$teamCount teams'),
                const SizedBox(width: 8),
                _PreviewChip(icon: Icons.sports_soccer, label: '$fixtureCount fixtures'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Open league'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
