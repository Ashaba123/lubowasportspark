
import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/api/app_api_provider.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/app_state.dart';
import 'package:lubowa_sports_park/core/theme/app_theme.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/activities/activities_screen.dart';
import 'package:lubowa_sports_park/features/about/about_screen.dart';
import 'package:lubowa_sports_park/features/booking/booking_form_screen.dart';
import 'package:lubowa_sports_park/features/contact/contact_screen.dart';
import 'package:lubowa_sports_park/features/events/events_screen.dart';
import 'package:lubowa_sports_park/features/home/home_screen.dart';
import 'package:lubowa_sports_park/features/league/league_screen.dart';
import 'package:lubowa_sports_park/features/onboarding/onboarding_screen.dart';
import 'package:lubowa_sports_park/features/settings/profile_settings_screen.dart';
import 'package:lubowa_sports_park/features/settings/settings_screen.dart';
import 'package:lubowa_sports_park/features/splash/splash_screen.dart';
import 'package:lubowa_sports_park/shared/textured_background.dart';
import 'package:lubowa_sports_park/shared/responsive_app_frame.dart';

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiClient _apiClient = createAppApiClient(
    tokenGetter: () => widget.tokenStorage.currentToken,
    onUnauthorized: () => widget.tokenStorage.clear(),
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<TokenStorage>.value(value: widget.tokenStorage),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ],
      child: Consumer<AppState>(
        builder: (BuildContext context, AppState appState, Widget? _) {
          return MaterialApp(
            title: 'Lubowa Sports Park',
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            darkTheme: AppTheme.dark,
            themeMode: appState.themeMode,
            navigatorKey: _navigatorKey,
            builder: (
              BuildContext context,
              Widget? child,
            ) => _ConnectivityPopupHost(
              navigatorKey: _navigatorKey,
              child: ResponsiveAppFrame(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

class _ConnectivityPopupHost extends StatefulWidget {
  const _ConnectivityPopupHost({
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<_ConnectivityPopupHost> createState() => _ConnectivityPopupHostState();
}

class _ConnectivityPopupHostState extends State<_ConnectivityPopupHost> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOfflineDialogVisible = false;
  @override
  void initState() {
    super.initState();
    _connectivitySubscription = onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
    _checkInitialConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final bool isConnected = _hasConnection(results);
    if (isConnected) {
      _hideOfflineDialog();
      return;
    }
    _showOfflineDialog();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((ConnectivityResult result) {
      return result != ConnectivityResult.none;
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final bool isConnected = await hasNetworkConnectivity();
    if (!mounted || isConnected) return;
    _showOfflineDialog();
  }

  void _showOfflineDialog() {
    if (_isOfflineDialogVisible) return;
    final BuildContext? dialogContext = widget.navigatorKey.currentContext;
    if (dialogContext == null) return;
    _isOfflineDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No internet connection'),
            content: const Text(
              'Please connect to the internet to continue using the app.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final bool isConnected = await hasNetworkConnectivity();
                  if (!context.mounted || !isConnected) return;
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text('I connected'),
              ),
            ],
          );
        },
      ).whenComplete(() {
        _isOfflineDialogVisible = false;
      }),
    );
  }

  void _hideOfflineDialog() {
    if (!_isOfflineDialogVisible) return;
    final NavigatorState? navigator = widget.navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    if (appState.showSplash) {
      return SplashScreen(
        onDone: appState.handleSplashDone,
        duration: AppState.splashDuration,
      );
    }
    if (appState.showOnboarding) {
      return OnboardingScreen(onDone: appState.handleOnboardingDone);
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.onToggleTheme,
    this.isDark,
  });

  // These are kept for backwards compatibility with existing tests and
  // call sites; AppState now owns the actual theme state.
  // ignore: unused_field
  final VoidCallback? onToggleTheme;
  // ignore: unused_field
  final bool? isDark;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final int index = appState.tabIndex;
    final tabs = [
      HomeScreen(
        onNavigateToTab: appState.selectTab,
        onToggleTheme: appState.toggleTheme,
        isDark: appState.isDark,
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
            final bool visible = entry.key == index;
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
        selectedIndex: index,
        onDestinationSelected: appState.selectTab,
        isDark: appState.isDark,
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
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Account & league profile',
            iconColor: cs.primary,
            iconBg: cs.primary.withValues(alpha: 0.12),
            isPrimary: false,
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const ProfileGateScreen()),
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
            subtitle: 'Policies & rules',
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
