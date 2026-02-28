import 'package:flutter/material.dart';

import '../../core/api/pages_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/wp_page.dart';
import '../../core/utils/html_utils.dart';
import '../../shared/wp_page_content.dart';

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
        body: const Center(child: CircularProgressIndicator()),
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
      final title = HtmlUtils.strip(page.title).isEmpty ? 'About Us' : HtmlUtils.strip(page.title);
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: WpPageContent(page: page),
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
