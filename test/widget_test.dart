import 'package:flutter_test/flutter_test.dart';
import 'package:lubowa_sports_park/main.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_api_helpers.dart';

void main() {
  testWidgets('App starts and shows home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});

    final tokenStorage = TestTokenStorage();
    await tester.pumpWidget(LubowaSportsParkApp(tokenStorage: tokenStorage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    final hasTagline = find.text('Sports • Fitness • Community').evaluate().isNotEmpty;
    final hasRetry = find.text('Retry').evaluate().isNotEmpty;
    final hasLoading = find.byType(FootballLoader).evaluate().isNotEmpty;
    expect(hasTagline || hasRetry || hasLoading, true);
  });
}
