import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../shared/page_transitions.dart';
import 'league_manage_screen.dart';
import 'league_repository.dart';
import 'login_screen.dart';

/// League: public (enter code → standings/results) and manage (login → create league, my leagues, my teams).
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late final LeagueRepository _repository =
      LeagueRepository(apiClient: context.read<ApiClient>());

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

