import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/api/pages_repository.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/core/models/wp_page.dart';
import 'package:lubowa_sports_park/core/utils/html_utils.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/events/event_detail_screen.dart';
import 'package:lubowa_sports_park/features/events/events_repository.dart';
import 'package:lubowa_sports_park/features/events/models/wp_post.dart';

/// Events: intro from wp page (events1) + list from wp/v2/posts. List + detail + pull-to-refresh.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

enum _EventFilter { upcoming, past }

class _EventsScreenState extends State<EventsScreen> {
  EventsRepository? _repository;
  PagesRepository? _pagesRepository;
  List<WpPost> _posts = [];
  WpPage? _eventsPage;
  bool _loading = true;
  String? _error;
  _EventFilter _filter = _EventFilter.upcoming;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository == null) {
      final api = context.read<ApiClient>();
      _repository = EventsRepository(apiClient: api);
      _pagesRepository = PagesRepository(apiClient: api);
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted || _repository == null || _pagesRepository == null) return;
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
        _repository!.getPosts(forceRefresh: true),
        _pagesRepository!.getPageBySlug(AppConstants.slugEventsPage, forceRefresh: true),
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

  List<WpPost> get _filteredPosts {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_filter == _EventFilter.upcoming) {
      return _posts.where((p) {
        final d = DateTime.tryParse(p.date);
        return d == null || !d.isBefore(today);
      }).toList();
    } else {
      return _posts.where((p) {
        final d = DateTime.tryParse(p.date);
        return d != null && d.isBefore(today);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Events')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty) {
      return _EventsSkeleton(theme: Theme.of(context));
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
    final visible = _filteredPosts;
    return Column(
      children: [
        _FilterTabs(
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: _posts.isEmpty && _eventsPage == null
              ? _buildEmptyState(allEmpty: true)
              : visible.isEmpty
                  ? _buildEmptyState(allEmpty: false)
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: 1 + visible.length,
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildEventsIntro();
                          final post = visible[index - 1];
                          final title = HtmlUtils.strip(post.title);
                          final hasImage = post.featuredMediaUrl != null && post.featuredMediaUrl!.isNotEmpty;
                          final dateText = post.date.isNotEmpty ? _formatDate(post.date) : null;
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 60 * index),
                            duration: const Duration(milliseconds: 380),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                  fadeSlideRoute(builder: (_) => EventDetailScreen(post: post)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasImage)
                                      Stack(
                                        children: [
                                          Image.network(
                                            post.featuredMediaUrl!,
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _eventPlaceholder(180),
                                          ),
                                          if (dateText != null)
                                            Positioned(
                                              left: 12,
                                              top: 12,
                                              child: _EventDateChip(text: dateText),
                                            ),
                                        ],
                                      )
                                    else
                                      _eventPlaceholder(140),
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
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _eventPlaceholder(double height) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
          child: Opacity(
        opacity: 0.9,
        child: Image.asset(
          'assets/logo.png',
          height: 64,
          fit: BoxFit.contain,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
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

  Widget _buildEmptyState({required bool allEmpty}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final String message = allEmpty
        ? 'Check back soon for upcoming events at Lubowa Sports Park.'
        : _filter == _EventFilter.upcoming
            ? 'No upcoming events right now. Check back soon.'
            : 'No past events to show yet.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No events',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});

  final _EventFilter selected;
  final ValueChanged<_EventFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<_EventFilter>(
        segments: const [
          ButtonSegment(value: _EventFilter.upcoming, label: Text('Upcoming'), icon: Icon(Icons.event_outlined)),
          ButtonSegment(value: _EventFilter.past, label: Text('Past'), icon: Icon(Icons.history_outlined)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? cs.primaryContainer : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading state using theme colors. No per-frame rebuilds.
class _EventsSkeleton extends StatelessWidget {
  const _EventsSkeleton({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: cs.surfaceContainerHighest,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: theme.textTheme.titleMedium?.fontSize ?? 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: theme.textTheme.bodyMedium?.fontSize ?? 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventDateChip extends StatelessWidget {
  const _EventDateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
