import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/app_api_provider.dart';
import 'core/auth/token_storage.dart';
import 'core/onboarding/onboarding_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/activities/activities_screen.dart';
import 'features/about/about_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/contact/contact_screen.dart';
import 'features/events/events_screen.dart';
import 'features/home/home_screen.dart';
import 'features/league/league_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'shared/textured_background.dart';

void main() {
  runApp(const LubowaSportsParkApp());
}

class LubowaSportsParkApp extends StatefulWidget {
  const LubowaSportsParkApp({super.key});

  @override
  State<LubowaSportsParkApp> createState() => _LubowaSportsParkAppState();
}

class _LubowaSportsParkAppState extends State<LubowaSportsParkApp> {
  late final InMemoryTokenStorage _tokenStorage = InMemoryTokenStorage();
  late final ApiClient _apiClient = createAppApiClient(
    tokenGetter: () => _tokenStorage.currentToken,
    onUnauthorized: () => _tokenStorage.clear(),
  );

  @override
  Widget build(BuildContext context) {
    return AppApiProvider(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
      child: MaterialApp(
        title: 'Lubowa Sports Park',
        theme: AppTheme.light,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;
  bool _showOnboarding = false;

  static const _splashDuration = Duration(milliseconds: 2200);

  void _onSplashDone() async {
    final completed = await OnboardingStorage.hasCompleted();
    if (!mounted) return;
    setState(() {
      _showSplash = false;
      _showOnboarding = !completed;
    });
  }

  void _onOnboardingDone() async {
    await OnboardingStorage.setCompleted();
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onDone: _onSplashDone,
        duration: _splashDuration,
      );
    }
    if (_showOnboarding) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onNavigateToTab: (i) => setState(() => _index = i)),
      const EventsScreen(),
      const BookingScreen(),
      const LeagueScreen(),
      const _MoreTab(),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const TexturedBackground(),
          IndexedStack(
            index: _index,
            children: tabs,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Events'),
                  NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Book'),
                  NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'League'),
                  NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'More'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _MoreCard(
            icon: Icons.sports_soccer,
            title: 'Activities',
            subtitle: 'Futsal, Car Wash, Training, Events',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.info_outline,
            title: 'About Us',
            subtitle: 'Who we are and what we stand for',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.contact_mail_outlined,
            title: 'Contact',
            subtitle: 'Get in touch with us',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
