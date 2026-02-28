import 'package:flutter/material.dart';

import 'models/wp_post.dart';

/// Event (WP post) detail: title, date, featured image, content.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.post});

  final WpPost post;

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = post.date.isNotEmpty
        ? _tryFormatDate(post.date)
        : '';

    return Scaffold(
      appBar: AppBar(title: Text(_stripHtml(post.title).isEmpty ? 'Event' : _stripHtml(post.title))),
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
                  const SizedBox(height: 12),
                  Text(
                    _stripHtml(post.content),
                    style: theme.textTheme.bodyLarge,
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
