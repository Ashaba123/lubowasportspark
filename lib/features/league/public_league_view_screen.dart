import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_repository.dart';
import 'public_league_screen.dart';

/// Dedicated screen for public view of leagues: enter code → view standings, results, top scorers.
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
      setState(
          () => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final data =
          await _repository.getPublicLeague(code, forceRefresh: true);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        fadeSlideRoute(
          builder: (_) => PublicLeagueScreen(
            data: data,
            repository: _repository,
          ),
        ),
      );
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            '${userFriendlyApiErrorMessage(e)}\n\nRaw (share if needed): $e\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    Text(
                      'Public league stats',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a league code to see standings, fixtures, and top scorers. No login needed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onSubmitted: (_) => _loadByCode(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _loading ? null : _loadByCode,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, 48),
                          ),
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
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.error),
                      ),
                    ],
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
