import 'package:flutter/material.dart';

import '../../core/api/pages_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/wp_page.dart';
import '../../shared/app_logo.dart';
import '../../shared/glass_container.dart';
import '../../shared/wp_page_content.dart';

/// Home tab: content from WordPress front page. Fallback to tagline if fetch fails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PagesRepository _repository = PagesRepository();
  WpPage? _page;
  bool _loading = true;
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
      final page = await _repository.getPageBySlug(AppConstants.slugFrontPage);
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
    if (_loading && _page == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 120),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    if (_page != null) {
      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppLogo(size: 140),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: WpPageContent(page: _page!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlassContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogo(size: 160),
                    const SizedBox(height: 24),
                    Text(
                      'Play • Train • Compete',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sports • Fitness • Community',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Could not load latest from website.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
