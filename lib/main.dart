import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/api/app_api_provider.dart';
import 'core/auth/token_storage.dart';
import 'core/onboarding/onboarding_storage.dart';
import 'core/theme/app_theme.dart';
import 'shared/page_transitions.dart';
import 'features/activities/activities_screen.dart';
import 'features/about/about_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/contact/contact_screen.dart';
import 'features/events/events_screen.dart';
import 'features/home/home_screen.dart';
import 'features/league/league_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'shared/textured_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokenStorage = SharedPreferencesTokenStorage();
  await tokenStorage.getToken();
  runApp(LubowaSportsParkApp(tokenStorage: tokenStorage));
}

class LubowaSportsParkApp extends StatefulWidget {
  const LubowaSportsParkApp({super.key, required this.tokenStorage});

  final TokenStorage tokenStorage;

  @override
  State<LubowaSportsParkApp> createState() => _LubowaSportsParkAppState();
}

class _LubowaSportsParkAppState extends State<LubowaSportsParkApp> {
  late final ApiClient _apiClient = createAppApiClient(
    tokenGetter: () => widget.tokenStorage.currentToken,
    onUnauthorized: () => widget.tokenStorage.clear(),
  );

  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<TokenStorage>.value(value: widget.tokenStorage),
      ],
      child: MaterialApp(
        title: 'Lubowa Sports Park',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        home: _AppRoot(
          onToggleTheme: _toggleTheme,
          isDark: _themeMode == ThemeMode.dark,
        ),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.onToggleTheme, required this.isDark});

  final VoidCallback onToggleTheme;
  final bool isDark;

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
    return MainShell(onToggleTheme: widget.onToggleTheme, isDark: widget.isDark);
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.onToggleTheme, required this.isDark});

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        onNavigateToTab: (i) => setState(() => _index = i),
        onToggleTheme: widget.onToggleTheme,
        isDark: widget.isDark,
      ),
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
          // AnimatedOpacity on each child keeps all tabs alive (IndexedStack
          // behaviour) while cross-fading when the selected index changes.
          ...tabs.asMap().entries.map((entry) {
            final visible = entry.key == _index;
            return AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !visible,
                child: entry.value,
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: _GradientNavBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        isDark: widget.isDark,
      ),
    );
  }
}

class _GradientNavBar extends StatelessWidget {
  const _GradientNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isDark,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;

  static const _destinations = [
    (icon: Icons.home_outlined,         filled: Icons.home,          label: 'Home'),
    (icon: Icons.event_outlined,        filled: Icons.event,         label: 'Events'),
    (icon: Icons.calendar_today_outlined, filled: Icons.calendar_today, label: 'Book'),
    (icon: Icons.emoji_events_outlined, filled: Icons.emoji_events,  label: 'League'),
    (icon: Icons.grid_view_outlined,    filled: Icons.grid_view,     label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final navForeground = theme.colorScheme.onPrimary;

    // Gradient stops: deep green → teal, subtler in dark mode
    final gradStart = isDark
        ? const Color(0xFF1B3A1F)   // dark forest
        : const Color(0xFF2E7D32);  // brand primary
    final gradEnd = isDark
        ? const Color(0xFF0D3330)   // dark teal
        : const Color(0xFF00695C);  // secondary teal

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: PhysicalModel(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        elevation: 16,
        shadowColor: gradStart.withValues(alpha: isDark ? 0.4 : 0.45),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradStart.withValues(alpha: isDark ? 0.92 : 0.96),
                    gradEnd.withValues(alpha: isDark ? 0.92 : 0.96),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                  width: 1,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_destinations.length, (i) {
                      final dest = _destinations[i];
                      final selected = i == selectedIndex;
                      return _NavItem(
                        icon: dest.icon,
                        filledIcon: dest.filled,
                        label: dest.label,
                        selected: selected,
                        textTheme: tt,
                        foregroundColor: navForeground,
                        onTap: () => onDestinationSelected(i),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.textTheme,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final TextTheme textTheme;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 12,
          vertical: 6,
        ),
        decoration: selected
            ? BoxDecoration(
                color: foregroundColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? filledIcon : icon,
                key: ValueKey(selected),
                color: foregroundColor.withValues(alpha: selected ? 1.0 : 0.65),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                color: foregroundColor.withValues(alpha: selected ? 1.0 : 0.65),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 10,
              ),
              child: Text(label),
            ),
          ],
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
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Quick links',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.sports_soccer,
            title: 'Activities',
            subtitle: 'Futsal, Car Wash, Training, Events',
            iconColor: cs.primary,
            iconBg: cs.primary.withValues(alpha: 0.12),
            isPrimary: false,
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const ActivitiesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.info_outline,
            title: 'About Us',
            subtitle: 'Who we are and what we stand for',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            isPrimary: false,
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.contact_mail_outlined,
            title: 'Contact',
            subtitle: 'Get in touch with us',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            isPrimary: false,
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const ContactScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Profile, policies & rules',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            isPrimary: false,
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const SettingsScreen()),
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
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final bool isPrimary;
  final VoidCallback onTap;

  static const _minHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
    if (isPrimary) {
      return Card(
        margin: EdgeInsets.zero,
        color: cs.primaryContainer.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minHeight),
            child: content,
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: content,
        ),
      ),
    );
  }
}
