/// Simple HTML stripping for WordPress rendered content.
/// Removes script/style blocks (and their content) so WPForms/JS don't show as text.
class HtmlUtils {
  HtmlUtils._();

  static final RegExp _scriptBlock = RegExp(
    r'<script[^>]*>[\s\S]*?</script>',
    caseSensitive: false,
  );
  static final RegExp _styleBlock = RegExp(
    r'<style[^>]*>[\s\S]*?</style>',
    caseSensitive: false,
  );

  static String strip(String html) {
    String s = html
        .replaceAll(_scriptBlock, '')
        .replaceAll(_styleBlock, '')
        .replaceAll(RegExp(r'</(?:p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
    // Drop common form-plugin boilerplate that can appear as plain text
    const formNoise = [
      'Please enable JavaScript in your browser to complete this form.',
    ];
    for (final phrase in formNoise) {
      s = s.replaceAll(phrase, '').trim();
    }
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();
    return s;
  }

  /// Removes script/style blocks only. Use before passing HTML to HtmlWidget
  /// so embedded forms/JS don't run or show as text.
  static String sanitizeForRender(String html) {
    return html
        .replaceAll(_scriptBlock, '')
        .replaceAll(_styleBlock, '');
  }
}
