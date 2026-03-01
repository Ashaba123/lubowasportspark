import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/html_utils.dart';
import 'models/wp_post.dart';

/// Event (WP post) detail: title, date, featured image, HTML content.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.post});

  final WpPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = HtmlUtils.strip(post.title);
    final dateStr = post.date.isNotEmpty ? _tryFormatDate(post.date) : '';
    final html = HtmlUtils.sanitizeForRender(post.content);

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Event' : title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.featuredMediaUrl != null && post.featuredMediaUrl!.isNotEmpty)
              Image.network(
                post.featuredMediaUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(height: 200),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dateStr.isNotEmpty)
                    Text(dateStr, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  if (dateStr.isNotEmpty) const SizedBox(height: 12),
                  if (html.isEmpty)
                    const SizedBox.shrink()
                  else
                    HtmlWidget(
                      html,
                      textStyle: theme.textTheme.bodyLarge,
                      baseUrl: Uri.parse('${AppConstants.websiteUrl}/'),
                    ),
                ],
              ),
            ),
          ],
        ),
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
