import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/api/api_client.dart';

/// **State / DI:** The app uses [Provider] for dependency injection throughout.
/// [ApiClient] and [TokenStorage] are provided at the root in [main.dart] via [MultiProvider].
/// Screens and widgets obtain them with [context.read<ApiClient>()] and [context.read<TokenStorage>()].
/// This file only defines [createAppApiClient], used in [main.dart] to build the [ApiClient] instance.

/// Creates [ApiClient] with [tokenGetter] (sync, e.g. from [InMemoryTokenStorage.currentToken]) and [onUnauthorized].
ApiClient createAppApiClient({
  required String? Function() tokenGetter,
  void Function()? onUnauthorized,
}) {
  return ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    tokenGetter: tokenGetter,
    onUnauthorized: onUnauthorized,
  );
}
