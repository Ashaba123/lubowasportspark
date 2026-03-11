import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/settings/league_booking_rules_screen.dart';
import 'package:lubowa_sports_park/features/settings/park_rules_screen.dart';
import 'package:lubowa_sports_park/features/settings/privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Policies & rules',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data and privacy',
            iconColor: cs.secondary,
            iconBg: cs.secondary.withValues(alpha: 0.12),
            isPrimary: false,
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
            isPrimary: false,
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
            isPrimary: false,
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

