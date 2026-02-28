import 'package:flutter/material.dart';

/// Activities offered at Lubowa Sports Park — aligns with website.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = [
      _ActivityItem(title: 'Futsal', subtitle: '5-a-side football', icon: Icons.sports_soccer),
      _ActivityItem(title: 'Car Wash', subtitle: 'LSP Car Wash on site', icon: Icons.local_car_wash),
      _ActivityItem(title: 'Training', subtitle: 'Sessions and coaching', icon: Icons.fitness_center),
      _ActivityItem(title: 'Events', subtitle: 'Tournaments and community events', icon: Icons.emoji_events),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final a = activities[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(a.icon, color: theme.colorScheme.primary),
              ),
              title: Text(a.title, style: theme.textTheme.titleMedium),
              subtitle: Text(a.subtitle, style: theme.textTheme.bodySmall),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
}
