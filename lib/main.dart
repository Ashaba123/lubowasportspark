import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/app_api_provider.dart';
import 'core/auth/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/activities/activities_screen.dart';
import 'features/about/about_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/contact/contact_screen.dart';
import 'features/events/events_screen.dart';
import 'features/home/home_screen.dart';
import 'features/league/league_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onDone: () => setState(() => _showSplash = false),
      );
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
      body: Stack(
        children: [
          const TexturedBackground(),
          IndexedStack(
            index: _index,
            children: tabs,
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
                NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Book'),
                NavigationDestination(icon: Icon(Icons.emoji_events), label: 'League'),
                NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
              ],
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
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.sports_soccer),
            title: const Text('Activities'),
            subtitle: const Text('Futsal, Car Wash, Training, Events'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Us'),
            subtitle: const Text('Who we are'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: const Text('Contact'),
            subtitle: const Text('Get in touch'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
