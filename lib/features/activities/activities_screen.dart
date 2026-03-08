import 'package:flutter/material.dart';

/// Activities — uses static highlight cards only (no API page content).
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Activities')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activities',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore the activities available at Lubowa Sports Park.\nDesigned for sports, leisure, and convenience.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const _ActivityHighlightCard(
              icon: Icons.sports_soccer,
              title: 'Futsal',
              subtitle: 'Quality pitches for casual games, training, and leagues.',
            ),
            const _ActivityHighlightCard(
              icon: Icons.local_car_wash,
              title: 'Car Wash',
              subtitle: 'Convenient car wash services while you train or relax.',
            ),
            const _ActivityHighlightCard(
              icon: Icons.fitness_center,
              title: 'Training',
              subtitle: 'Coaching and fitness sessions for different ages and levels.',
            ),
            const _ActivityHighlightCard(
              icon: Icons.event,
              title: 'Events',
              subtitle: 'Host corporate, social, and community events in our spaces.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHighlightCard extends StatelessWidget {
  const _ActivityHighlightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
