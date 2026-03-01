import 'package:flutter/material.dart';

/// Onboarding flow: 3 pages with dots, Continue / Skip / Get started.
/// Calls [onDone] when user taps Get started or Skip (after persisting completion).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
  });

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.map_outlined,
                    title: 'Find courts & facilities',
                    body: 'Discover pitches and facilities at Lubowa Sports Park with real-time availability.',
                  ),
                  _OnboardingPage(
                    icon: Icons.calendar_today_outlined,
                    title: 'Easy booking',
                    body: 'Reserve the pitch or courts in a few taps. Choose date and time that works for you.',
                  ),
                  _OnboardingPage(
                    icon: Icons.emoji_events_outlined,
                    title: 'Leagues & events',
                    body: 'Join leagues, view standings, and stay up to date with events and activities.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pageCount, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (_currentPage < _pageCount - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        widget.onDone();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pageCount - 1 ? 'Continue' : 'Get started',
                    ),
                  ),
                  if (_currentPage < _pageCount - 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onDone,
                      child: Text(
                        'Skip',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
