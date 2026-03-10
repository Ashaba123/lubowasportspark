import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'league_manage_screen.dart';
import 'league_repository.dart';
import 'login_screen.dart';
import 'public_league_screen.dart';

/// League: public (enter code → standings/results) and manage (login → create league, my leagues, my teams).
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
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
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final data = await _repository.getPublicLeague(code, forceRefresh: true);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        fadeSlideRoute(builder: (_) => PublicLeagueScreen(data: data)),
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
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: colorScheme.onPrimary),
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
                            backgroundColor:
                                colorScheme.surface.withValues(alpha: 0.9),
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
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.error),
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
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_circle,
                              color: colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Login to manage a league',
                                  style: theme.textTheme.titleMedium),
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
                        final tokenStorage = context.read<TokenStorage>();
                        final token = await tokenStorage.getToken();
                        if (mounted && token != null && token.isNotEmpty) {
                          await navigator.push(
                            fadeSlideRoute(
                              builder: (_) =>
                                  LeagueManageScreen(repository: _repository),
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
                              builder: (_) =>
                                  LeagueManageScreen(repository: _repository),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Manage leagues'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

