/// WordPress REST API post (wp/v2/posts). Used for events.
class WpPost {
  const WpPost({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.excerpt,
    this.featuredMediaId,
    this.featuredMediaUrl,
  });

  final int id;
  final String title;
  final String content;
  final String date;
  final String? excerpt;
  final int? featuredMediaId;
  final String? featuredMediaUrl;

  factory WpPost.fromJson(Map<String, dynamic> json) {
    final titleObj = json['title'] as Map<String, dynamic>?;
    final contentObj = json['content'] as Map<String, dynamic>?;
    final excerptObj = json['excerpt'] as Map<String, dynamic>?;
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    List<dynamic>? featuredMedia;
    if (embedded != null) {
      featuredMedia = embedded['wp:featuredmedia'] as List<dynamic>?;
    }
    final media = (featuredMedia != null && featuredMedia.isNotEmpty)
        ? featuredMedia[0] as Map<String, dynamic>?
        : null;
    final sourceUrl = media?['source_url'] as String?;

    return WpPost(
      id: json['id'] as int,
      title: (titleObj?['rendered'] as String?) ?? '',
      content: (contentObj?['rendered'] as String?) ?? '',
      date: (json['date'] as String?) ?? '',
      excerpt: excerptObj?['rendered'] as String?,
      featuredMediaId: json['featured_media'] as int?,
      featuredMediaUrl: sourceUrl,
    );
  }
}
