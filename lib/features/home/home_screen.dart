import 'package:flutter/material.dart';

import '../../shared/app_logo.dart';

/// Home tab: logo + tagline + 3–4 action cards. Mobile-first.
/// [onNavigateToTab] switches bottom nav (1=Events, 2=Book, 3=League, 4=More).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  final void Function(int tabIndex)? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const AppLogo(size: 120),
              const SizedBox(height: 16),
              Text(
                'Play • Train • Compete',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Sports • Fitness • Community',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onNavigateToTab != null) ...[
                _ActionCard(
                  icon: Icons.event,
                  title: 'Events',
                  subtitle: 'Upcoming and past events',
                  onTap: () => onNavigateToTab!(1),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.calendar_today,
                  title: 'Book',
                  subtitle: 'Reserve the pitch or facilities',
                  onTap: () => onNavigateToTab!(2),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.emoji_events,
                  title: 'League',
                  subtitle: 'View standings or manage leagues',
                  onTap: () => onNavigateToTab!(3),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.more_horiz,
                  title: 'More',
                  subtitle: 'Activities, About us, Contact',
                  onTap: () => onNavigateToTab!(4),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hours', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Monday – Friday · 6AM – 10PM\nSaturday – Sunday · 7AM – 11PM',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 28),
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
