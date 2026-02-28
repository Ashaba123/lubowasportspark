import 'package:flutter/material.dart';

import '../core/models/wp_page.dart';
import '../core/utils/html_utils.dart';

/// Displays a WordPress page: optional featured image and stripped content.
class WpPageContent extends StatelessWidget {
  const WpPageContent({super.key, required this.page});

  final WpPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = HtmlUtils.strip(page.content);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (page.featuredMediaUrl != null && page.featuredMediaUrl!.isNotEmpty)
            Image.network(
              page.featuredMediaUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content.isEmpty
                ? const SizedBox.shrink()
                : Text(content, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
