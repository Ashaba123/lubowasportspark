/// Simple HTML stripping for WordPress rendered content.
class HtmlUtils {
  HtmlUtils._();

  static String strip(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
