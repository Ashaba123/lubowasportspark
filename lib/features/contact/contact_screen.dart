import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/pages_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/wp_page.dart';
import '../../core/utils/html_utils.dart';
import '../../shared/wp_page_content.dart';

/// Contact — content from WordPress page (slug: contact) + link to website contact.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final PagesRepository _repository = PagesRepository();
  bool _loading = true;
  WpPage? _page;
  Object? _error;

  static String get _contactUrl =>
      '${AppConstants.websiteUrl}${AppConstants.websiteContactPath}';

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
    try {
      final page = await _repository.getPageBySlug(AppConstants.slugContact);
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

  Future<void> _openContactPage(BuildContext context) async {
    final uri = Uri.parse(_contactUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error.toString(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
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
      final title = HtmlUtils.strip(page.title).isEmpty ? 'Contact' : HtmlUtils.strip(page.title);
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WpPageContent(page: page),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => _openContactPage(context),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open contact page on website'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get in touch with us at Lubowa Sports Park.', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openContactPage(context),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open contact page on website'),
            ),
          ],
        ),
      ),
    );
  }
}
