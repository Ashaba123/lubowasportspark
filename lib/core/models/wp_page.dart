/// WordPress REST API page (wp/v2/pages). Same response shape as posts.
class WpPage {
  const WpPage({
    required this.id,
    required this.title,
    required this.content,
    this.featuredMediaId,
    this.featuredMediaUrl,
  });

  final int id;
  final String title;
  final String content;
  final int? featuredMediaId;
  final String? featuredMediaUrl;

  factory WpPage.fromJson(Map<String, dynamic> json) {
    final titleObj = json['title'] as Map<String, dynamic>?;
    final contentObj = json['content'] as Map<String, dynamic>?;
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    List<dynamic>? featuredMedia;
    if (embedded != null) {
      featuredMedia = embedded['wp:featuredmedia'] as List<dynamic>?;
    }
    final media = (featuredMedia != null && featuredMedia.isNotEmpty)
        ? featuredMedia[0] as Map<String, dynamic>
        : null;
    final sourceUrl = media?['source_url'] as String?;

    return WpPage(
      id: json['id'] as int,
      title: (titleObj?['rendered'] as String?) ?? '',
      content: (contentObj?['rendered'] as String?) ?? '',
      featuredMediaId: json['featured_media'] as int?,
      featuredMediaUrl: sourceUrl,
    );
  }
}
