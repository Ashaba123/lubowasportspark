import 'package:flutter/material.dart';

class ParkRulesScreen extends StatelessWidget {
  const ParkRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Park Rules')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Park Rules',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'To keep Lubowa Sports Park safe, welcoming, and enjoyable for everyone, please follow these guidelines when using the facilities.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'General conduct',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'Respect staff, referees, coaches, and other visitors at all times.'),
            _Bullet(
              text:
                  'Use appropriate language and avoid aggressive or abusive behaviour on and off the pitch.',
            ),
            _Bullet(
              text:
                  'Follow instructions from Lubowa Sports Park staff regarding safety, pitch use, and timings.',
            ),
            const SizedBox(height: 16),
            Text(
              'Safety & facilities',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'Use the pitches, equipment, and facilities only for their intended purpose.'),
            _Bullet(
              text:
                  'Wear appropriate footwear and gear for the surface and activity you are participating in.',
            ),
            _Bullet(
              text:
                  'Report any damage, spills, or safety concerns to staff as soon as you notice them.',
            ),
            const SizedBox(height: 16),
            Text(
              'Environment & community',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'Keep the park clean by using the bins provided and avoiding littering.'),
            _Bullet(
              text:
                  'Be mindful of noise levels, especially during early morning or late evening sessions.',
            ),
            _Bullet(
              text:
                  'Look out for younger players and families so that everyone can enjoy the space together.',
            ),
            const SizedBox(height: 16),
            Text(
              'Lubowa Sports Park may have additional detailed rules and policies. Those, where provided, will take priority over this summary.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

