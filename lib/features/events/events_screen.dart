import 'package:flutter/material.dart';

import '../../core/api/pages_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../core/models/wp_page.dart';
import '../../core/utils/html_utils.dart';
import 'event_detail_screen.dart';
import 'events_repository.dart';
import 'models/wp_post.dart';

/// Events: intro from wp page (events1) + list from wp/v2/posts. List + detail + pull-to-refresh.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventsRepository _repository = EventsRepository();
  final PagesRepository _pagesRepository = PagesRepository();
  List<WpPost> _posts = [];
  WpPage? _eventsPage;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!await hasNetworkConnectivity()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(NoConnectivityException());
      });
      return;
    }
    try {
      final results = await Future.wait([
        _repository.getPosts(),
        _pagesRepository.getPageBySlug(AppConstants.slugEventsPage),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<WpPost>;
        _eventsPage = results[1] as WpPage?;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty && _eventsPage == null) {
      return const Center(child: Text('No events right now.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 1 + _posts.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildEventsIntro();
          }
          final post = _posts[index - 1];
          final title = HtmlUtils.strip(post.title);
          final hasImage = post.featuredMediaUrl != null && post.featuredMediaUrl!.isNotEmpty;
          return Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EventDetailScreen(post: post)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage)
                    Image.network(
                      post.featuredMediaUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _eventPlaceholder(140),
                    )
                  else
                    _eventPlaceholder(100),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Event #${post.id}' : title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (post.date.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(post.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _eventPlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.event, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildEventsIntro() {
    final theme = Theme.of(context);
    if (_eventsPage == null) return const SizedBox(height: 4);
    final content = HtmlUtils.strip(_eventsPage!.content);
    if (content.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
