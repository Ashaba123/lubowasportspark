import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This page explains, in simple language, how the Lubowa Sports Park app may handle your information.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What we may collect',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'Basic contact details you provide for bookings (name, phone, email).'),
            _Bullet(
              text:
                  'League-related details such as team, fixtures, and player stats when you participate in leagues.',
            ),
            _Bullet(
              text:
                  'Technical information needed to run the app and communicate with the Lubowa Sports Park backend.',
            ),
            const SizedBox(height: 16),
            Text(
              'How we may use it',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'To manage bookings and respond to your requests.'),
            _Bullet(text: 'To run leagues, fixtures, standings, and player statistics.'),
            _Bullet(
              text:
                  'To improve the experience of the app and services at Lubowa Sports Park, where appropriate.',
            ),
            const SizedBox(height: 16),
            Text(
              'Your choices',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(
              text:
                  'You can choose what information you provide when making bookings or joining leagues.',
            ),
            _Bullet(
              text:
                  'You can reach out to the Lubowa Sports Park team if you have questions about how your data is used.',
            ),
            const SizedBox(height: 16),
            Text(
              'The final, legally binding privacy policy may be provided by Lubowa Sports Park and can replace this summary text.',
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

