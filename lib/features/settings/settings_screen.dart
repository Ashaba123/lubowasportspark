import 'package:flutter/material.dart';

import '../../shared/page_transitions.dart';
import 'league_booking_rules_screen.dart';
import 'park_rules_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _SettingsCard(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Account & profile (coming soon)',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const ProfileSettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data and privacy',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.rule_folder_outlined,
            title: 'League & Booking Rules',
            subtitle: 'Participation, bookings, cancellations & conduct',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const LeagueBookingRulesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.policy_outlined,
            title: 'Park Rules',
            subtitle: 'Using the facilities safely and respectfully',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            onTap: () => Navigator.of(context).push(
              fadeSlideRoute(builder: (_) => const ParkRulesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 26),
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

