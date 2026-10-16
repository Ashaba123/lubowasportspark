/// App constants. Base URL and secrets come from --dart-define or env, not hardcoded.
class AppConstants {
  AppConstants._();

  /// Default API base (override via --dart-define=API_BASE_URL=... or env).
  static const String defaultApiBaseUrl = 'https://lubowasportspark.com/wp-json';

  /// Key for dart-define / env: API_BASE_URL
  static const String apiBaseUrlKey = 'API_BASE_URL';

  /// API base URL used by the app. Override at build: --dart-define=API_BASE_URL=https://...
  static String get apiBaseUrl =>
      String.fromEnvironment(apiBaseUrlKey, defaultValue: defaultApiBaseUrl);

  /// Paths (relative to base URL)
  static const String pathPosts = '/wp/v2/posts';
  static const String pathPages = '/wp/v2/pages';
  static const String pathWpCurrentUser = '/wp/v2/users/me';
  static const String pathJwtToken = '/jwt-auth/v1/token';

  /// Bookings via Lubowa EA Bridge plugin (Easy!Appointments).
  static const String pathEaServices = '/lubowa-ea/v1/services';
  static const String pathEaSlots = '/lubowa-ea/v1/slots';
  static const String pathEaBookings = '/lubowa-ea/v1/bookings';
  static String pathEaLeagueBookings(int leagueId) => '/lubowa-ea/v1/leagues/$leagueId/bookings';

  /// Bookings are bookable this many days ahead (match EA → Booking Settings).
  static const int bookingMaxDaysAhead = 60;

  /// Lubowa API (leagues, users)
  static const String pathLubowaLeagues = '/lubowa/v1/leagues';
  static const String pathLubowaPublicLeague = '/lubowa/v1/public/leagues';
  static const String pathLubowaMeRoles = '/lubowa/v1/me/league_roles';
  static const String pathLubowaMePlayer = '/lubowa/v1/me/player';
  static const String pathLubowaSignup = '/lubowa/v1/signup';
  static const String pathLubowaGoogleLogin = '/lubowa/v1/google_login';

  /// WordPress page slugs for app screens (match site URLs: /, /activities/, /about-us/, /contact/, /events1/).
  static const String slugFrontPage = 'home';
  static const String slugActivities = 'activities';
  static const String slugEventsPage = 'events1';
  static const String slugAbout = 'about-us';
  static const String slugContact = 'contact';

  /// Website (for Contact, About, external links)
  static const String websiteUrl = 'https://lubowasportspark.com';
  static const String websiteContactPath = '/contact';
}
