import 'package:flutter_test/flutter_test.dart';

import 'package:lubowa_sports_park/features/booking/booking_form_screen.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  testWidgets('BookingScreen shows Book tab and landing content', (WidgetTester tester) async {
    final mockDio = MockDio();
    final apiClient = createTestApiClient(dio: mockDio);
    final tokenStorage = TestTokenStorage();

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        child: const BookingScreen(),
      ),
    );
    await tester.pump(); // didChangeDependencies

    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Book. Play. Enjoy.'), findsOneWidget);
  });

  testWidgets('BookingScreen has fade-in entrance animation', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: MockDio()),
        tokenStorage: TestTokenStorage(),
        child: const BookingScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(FadeSlideIn), findsOneWidget);
  });
}

