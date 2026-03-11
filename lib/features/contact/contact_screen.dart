import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';

/// Contact: static contact info, hours, and button to open the contact page.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: 'info@lubowasportspark.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+256781773771');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openContactPage() async {
    final uri = Uri.parse('${AppConstants.websiteUrl}${AppConstants.websiteContactPath}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Contact')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get in touch', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Reach us using the details below.',
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(Icons.location_on_outlined, color: colorScheme.primary),
                title: Text('Location', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  'Lubowa, Kigo Road',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.email_outlined, color: colorScheme.primary),
                title: Text('Email', style: theme.textTheme.titleMedium),
                subtitle: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'info@lubowasportspark.com',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                  ),
                ),
                onTap: _launchEmail,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.call_outlined, color: colorScheme.primary),
                title: Text('Call', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  '+256-781-773771 / +256-705-616868',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                onTap: _launchPhone,
              ),
            ),
            const SizedBox(height: 24),
            Text('Hours', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Monday – Friday · 6AM – 10PM\nSaturday – Sunday · 7AM – 11PM',
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openContactPage,
              icon: const Icon(Icons.contact_support_outlined),
              label: const Text('Contact Us'),
            ),
          ],
        ),
      ),
    );
  }
}
