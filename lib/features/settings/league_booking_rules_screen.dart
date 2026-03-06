import 'package:flutter/material.dart';

class LeagueBookingRulesScreen extends StatelessWidget {
  const LeagueBookingRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('League & Booking Rules')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'League & Booking Rules',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'These guidelines outline how bookings and league participation are expected to work at Lubowa Sports Park.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bookings',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(text: 'Bookings should be made in advance through the app or directly with the team.'),
            _Bullet(
              text:
                  'Please arrive on time for your booked slot so that the pitch and facilities can run on schedule.',
            ),
            _Bullet(
              text:
                  'If you need to cancel or change a booking, contact Lubowa Sports Park as early as possible.',
            ),
            const SizedBox(height: 16),
            Text(
              'Leagues & Fixtures',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(
              text:
                  'Teams and players must respect the fixtures, match times, and competition format communicated by the organisers.',
            ),
            _Bullet(
              text:
                  'Team leaders are responsible for registering players correctly and keeping their details up to date.',
            ),
            _Bullet(
              text:
                  'Scores, goals, and results are recorded in line with the official rules of the competition.',
            ),
            const SizedBox(height: 16),
            Text(
              'Conduct',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Bullet(
              text:
                  'Fair play, respect for referees, staff, and other teams is required at all times.',
            ),
            _Bullet(
              text:
                  'Abusive or dangerous behaviour can result in removal from fixtures, leagues, or future bookings.',
            ),
            const SizedBox(height: 16),
            Text(
              'The full, official rules for leagues and bookings may be provided separately by Lubowa Sports Park and can replace or extend this summary.',
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

