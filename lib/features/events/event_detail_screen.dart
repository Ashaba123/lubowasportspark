import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/html_utils.dart';
import 'models/wp_post.dart';

/// Event (WP post) detail: title, date, featured image, HTML content. Designed for clarity and hierarchy.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.post});

  final WpPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = HtmlUtils.strip(post.title);
    final dateStr = post.date.isNotEmpty ? _tryFormatDate(post.date) : '';
    final html = HtmlUtils.sanitizeForRender(post.content);
    final hasImage = post.featuredMediaUrl != null && post.featuredMediaUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? Image.network(
                      post.featuredMediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dateStr.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  if (dateStr.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    title.isEmpty ? 'Event' : title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  if (html.isNotEmpty)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: HtmlWidget(
                          html,
                          textStyle: theme.textTheme.bodyLarge,
                          baseUrl: Uri.parse('${AppConstants.websiteUrl}/'),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No further details for this event.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.event, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  static String _tryFormatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
