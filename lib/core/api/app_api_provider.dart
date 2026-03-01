import 'package:flutter/material.dart';

import '../auth/token_storage.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';

/// Provides [ApiClient] and [TokenStorage] to the widget tree.
/// Create in [main] with [TokenStorage] and optional [onUnauthorized] (e.g. clear token).
class AppApiProvider extends InheritedWidget {
  const AppApiProvider({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
    required super.child,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  static AppApiProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppApiProvider>();
    assert(provider != null, 'AppApiProvider not found. Wrap app with AppApiProvider.');
    return provider!;
  }

  static ApiClient apiClientOf(BuildContext context) => of(context).apiClient;
  static TokenStorage tokenStorageOf(BuildContext context) => of(context).tokenStorage;

  @override
  bool updateShouldNotify(AppApiProvider oldWidget) =>
      apiClient != oldWidget.apiClient || tokenStorage != oldWidget.tokenStorage;
}

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
