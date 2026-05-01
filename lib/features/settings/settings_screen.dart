import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/settings/league_booking_rules_screen.dart';
import 'package:lubowa_sports_park/features/settings/park_rules_screen.dart';
import 'package:lubowa_sports_park/features/settings/privacy_policy_screen.dart';

Future<void> _showFeedbackDialog(BuildContext context) async {
  final workedCtrl = TextEditingController();
  final didntCtrl = TextEditingController();
  final missingCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) => _FeedbackDialog(
      workedCtrl: workedCtrl,
      didntCtrl: didntCtrl,
      missingCtrl: missingCtrl,
    ),
  );

  workedCtrl.dispose();
  didntCtrl.dispose();
  missingCtrl.dispose();
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.workedCtrl,
    required this.didntCtrl,
    required this.missingCtrl,
  });

  final TextEditingController workedCtrl;
  final TextEditingController didntCtrl;
  final TextEditingController missingCtrl;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  bool _submitted = false;
  bool _sending = false;

  Future<void> _submit() async {
    final worked = widget.workedCtrl.text.trim();
    final didnt = widget.didntCtrl.text.trim();
    final missing = widget.missingCtrl.text.trim();
    if (worked.isEmpty && didnt.isEmpty && missing.isEmpty) return;

    setState(() => _sending = true);

    final body = [
      if (worked.isNotEmpty) 'What worked:\n$worked',
      if (didnt.isNotEmpty) "What didn't work:\n$didnt",
      if (missing.isNotEmpty) "What's missing:\n$missing",
    ].join('\n\n');

    final uri = Uri(
      scheme: 'mailto',
      path: 'info@lubowasportspark.com',
      queryParameters: {
        'subject': 'App Feedback — Lubowa Sports Park',
        'body': body,
      },
    );

    await launchUrl(uri);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_submitted) {
      return AlertDialog(
        title: const Text('Thanks!'),
        content: const Text('Your feedback has been sent. We appreciate it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Send Feedback'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Help us improve the app.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.workedCtrl,
              decoration: const InputDecoration(
                labelText: 'What worked?',
                hintText: 'e.g. booking flow was smooth',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.didntCtrl,
              decoration: const InputDecoration(
                labelText: "What didn't work?",
                hintText: 'e.g. had trouble finding events',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.missingCtrl,
              decoration: const InputDecoration(
                labelText: "What's missing?",
                hintText: 'e.g. notifications for bookings',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}

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
          const SizedBox(height: 24),
          Text(
            'Feedback',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Tell us what worked, what didn\'t, and what\'s missing',
            iconColor: cs.primary,
            iconBg: cs.primaryContainer.withValues(alpha: 0.5),
            isPrimary: false,
            onTap: () => _showFeedbackDialog(context),
          ),
          const SizedBox(height: 24),
          Text(
            'Account',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            subtitle: 'Request deletion of your account and data',
            iconColor: cs.error,
            iconBg: cs.error.withValues(alpha: 0.12),
            isPrimary: false,
            onTap: () => launchUrl(
              Uri.parse('https://lubowasportspark.com/delete-account/'),
              mode: LaunchMode.externalApplication,
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

