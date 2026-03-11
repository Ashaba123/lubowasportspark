import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/app_state.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/theme/app_theme.dart';
import 'package:lubowa_sports_park/main.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  testWidgets('MainShell shows bottom nav with 5 items', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: createTestApiClient()),
            Provider<TokenStorage>.value(value: TestTokenStorage()),
            ChangeNotifierProvider<AppState>(
              create: (_) => AppState(),
            ),
          ],
          child: MainShell(
            onToggleTheme: () {},
            isDark: false,
          ),
        ),
      ),
    );

    expect(find.byType(MainShell), findsOneWidget);
    // Nav has 5 items; use icons to avoid matching app bar titles (e.g. "Events")
    expect(find.byIcon(Icons.home), findsWidgets);
    expect(find.byIcon(Icons.event_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
  });

  testWidgets('MainShell uses app theme for nav', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: createTestApiClient()),
            Provider<TokenStorage>.value(value: TestTokenStorage()),
            ChangeNotifierProvider<AppState>(
              create: (_) => AppState(),
            ),
          ],
          child: MainShell(
            onToggleTheme: () {},
            isDark: false,
          ),
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);
    expect(materialApp.theme!.colorScheme.primary, AppTheme.light.colorScheme.primary);
  });
}
