import 'package:flutter/material.dart';

import '../../core/api/pages_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../core/models/wp_page.dart';
import '../../core/utils/html_utils.dart';
import '../../shared/wp_page_content.dart';
import '../../shared/football_loader.dart';

/// About Us — content from WordPress page (slug: about).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final PagesRepository _repository = PagesRepository();
  bool _loading = true;
  WpPage? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!await hasNetworkConnectivity()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = NoConnectivityException();
      });
      return;
    }
    try {
      final page = await _repository.getPageBySlug(AppConstants.slugAbout);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('About Us')),
        body: const Center(child: FootballLoader()),
      );
    }
    if (_error != null && _page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('About Us')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userFriendlyApiErrorMessage(_error), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (_page != null) {
      final page = _page!;
      final title = HtmlUtils.strip(page.title).isEmpty ? 'About Us' : HtmlUtils.strip(page.title);
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'More than just a sports park.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sports, fitness, and community in one modern destination.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _AboutInfoCard(
                    title: 'Community & Experience',
                    subtitle:
                        'Whether you are here to play, train, relax, or socialize, Lubowa Sports Park is designed to bring people together.',
                    icon: Icons.groups,
                  ),
                  const _AboutInfoCard(
                    title: 'Sports, Fitness & Training',
                    subtitle:
                        'From futsal and leagues to training sessions and fitness activities, there is something for every level.',
                    icon: Icons.sports,
                  ),
                  const _AboutInfoCard(
                    title: 'Family-Friendly Environment',
                    subtitle:
                        'Safe, welcoming spaces for families, friends, and teams to spend quality time on and off the pitch.',
                    icon: Icons.emoji_people,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: WpPageContent(page: page),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: const Center(child: Text('No content available.')),
    );
  }
}

class _AboutInfoCard extends StatelessWidget {
  const _AboutInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
