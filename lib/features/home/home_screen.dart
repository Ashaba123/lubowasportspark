import 'package:flutter/material.dart';

import '../../shared/app_logo.dart';

/// Home tab: logo + tagline + 3–4 action cards. Mobile-first.
/// [onNavigateToTab] switches bottom nav (1=Events, 2=Book, 3=League, 4=More).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.onToggleTheme,
    this.isDark = false,
  });

  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onToggleTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const AppLogo(size: 80),
                      const SizedBox(height: 16),
                      Text(
                        'Sports • Fitness • Community',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Lubowa Sports Park is a modern multi-sport facility offering '
                        'football, padel, fitness training, events, and community '
                        'activities for all ages.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.schedule, size: 16, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Mon–Fri 6AM–10PM  ·  Sat–Sun 7AM–11PM',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (onNavigateToTab != null) ...[
                        _ActionCard(
                          icon: Icons.calendar_today,
                          title: 'Book Now',
                          subtitle: 'Reserve the pitch or facilities',
                          onTap: () => onNavigateToTab!(2),
                          isAccent: true,
                        ),
                        const SizedBox(height: 12),
                        _ActionCard(
                          icon: Icons.event,
                          title: 'Events',
                          subtitle: 'Upcoming and past events',
                          onTap: () => onNavigateToTab!(1),
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
                          icon: Icons.grid_view,
                          title: 'More',
                          subtitle: 'Activities, About us, Contact',
                          onTap: () => onNavigateToTab!(4),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
            if (onToggleTheme != null)
              Positioned(
                top: 4,
                right: 4,
                child: Tooltip(
                  message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onToggleTheme,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            key: ValueKey(isDark),
                            color: cs.onSurface,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isAccent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isAccent;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.isAccent ? _buildAccent(theme, cs) : _buildDefault(theme, cs),
    );
  }

  Widget _buildAccent(ThemeData theme, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (h) => setState(() => _pressed = h),
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefault(ThemeData theme, ColorScheme cs) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (h) => setState(() => _pressed = h),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: cs.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
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
        ),
      ),
    );
  }
}
