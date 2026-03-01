import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lubowa_sports_park/core/api/app_api_provider.dart';
import 'package:lubowa_sports_park/features/booking/booking_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  testWidgets('BookingScreen shows Book tab and landing content', (WidgetTester tester) async {
    final mockDio = MockDio();
    final apiClient = createTestApiClient(dio: mockDio);
    final tokenStorage = TestTokenStorage();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: AppApiProvider(
          apiClient: apiClient,
          tokenStorage: tokenStorage,
          child: const BookingScreen(),
        ),
      ),
    );
    await tester.pump(); // didChangeDependencies

    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Book at Lubowa Sports Park'), findsOneWidget);
  });
}
