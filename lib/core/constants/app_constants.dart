/// App constants. Base URL and secrets come from --dart-define or env, not hardcoded.
class AppConstants {
  AppConstants._();

  /// Default API base (override via --dart-define=API_BASE_URL=... or env).
  static const String defaultApiBaseUrl = 'https://lubowasportspark.com/wp-json';

  /// Key for dart-define / env: API_BASE_URL
  static const String apiBaseUrlKey = 'API_BASE_URL';

  /// Paths (relative to base URL)
  static const String pathPosts = '/wp/v2/posts';
  static const String pathJwtToken = '/jwt-auth/v1/token';
}
