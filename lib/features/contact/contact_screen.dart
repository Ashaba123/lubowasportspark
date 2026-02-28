import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Contact — link to website contact page.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static String get _contactUrl =>
      '${AppConstants.websiteUrl}${AppConstants.websiteContactPath}';

  Future<void> _openContactPage(BuildContext context) async {
    final uri = Uri.parse(_contactUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get in touch with us at Lubowa Sports Park.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openContactPage(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open contact page on website'),
              ),
              const SizedBox(height: 16),
              Text(
                'lubowasportspark.com',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
