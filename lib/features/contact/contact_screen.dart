import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


/// Contact: WhatsApp + Maps quick actions, contact info, and hours.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse('https://wa.me/256781773771');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=Lubowa+Sports+Park+Kigo+Road+Kampala',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: 'info@lubowasportspark.com');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+256781773771');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Contact')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get in touch', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Reach us instantly via WhatsApp or find us on the map.',
              style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _launchWhatsApp,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Chat on WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _launchMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Get directions on Google Maps'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            Text('Contact details', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.location_on_outlined, color: cs.primary),
                title: Text('Location', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  'Lubowa, Kigo Road, Kampala',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                onTap: _launchMaps,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.email_outlined, color: cs.primary),
                title: Text('Email', style: theme.textTheme.titleMedium),
                subtitle: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'info@lubowasportspark.com',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                  ),
                ),
                onTap: _launchEmail,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.call_outlined, color: cs.primary),
                title: Text('Call', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  '+256-781-773771 / +256-705-616868',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                onTap: _launchPhone,
              ),
            ),
            const SizedBox(height: 24),
            Text('Hours', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Monday – Friday · 6AM – 10PM\nSaturday – Sunday · 7AM – 11PM',
              style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
