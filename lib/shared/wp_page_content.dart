import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../core/constants/app_constants.dart';
import '../core/models/wp_page.dart';
import '../core/utils/html_utils.dart';

/// Displays a WordPress page: featured image + HTML content (images, text, links).
class WpPageContent extends StatelessWidget {
  const WpPageContent({super.key, required this.page});

  final WpPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final html = HtmlUtils.sanitizeForRender(page.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
          child: html.isEmpty
              ? const SizedBox.shrink()
              : HtmlWidget(
                  html,
                  textStyle: theme.textTheme.bodyLarge,
                  baseUrl: Uri.parse('${AppConstants.websiteUrl}/'),
                ),
        ),
      ],
    );
  }
}
