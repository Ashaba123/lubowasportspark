import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/booking/booking_form_screen.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/shared/skeleton.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

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

  testWidgets('BookingScreen shows skeleton while services load', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final mockDio = MockDio();
    when(() => mockDio.get<dynamic>(AppConstants.pathEaServices))
        .thenAnswer((_) => Completer<Response<dynamic>>().future);

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: TestTokenStorage(),
        child: const BookingScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // past the entrance fade

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('BookingScreen shows chip skeleton while time slots load', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final mockDio = MockDio();
    when(() => mockDio.get<dynamic>(AppConstants.pathEaServices)).thenAnswer(
      (_) async => responseOk<dynamic>(<dynamic>[
        <String, dynamic>{'id': 1, 'name': 'Futsal', 'duration': 60},
      ]),
    );
    when(() => mockDio.get<dynamic>(
          AppConstants.pathEaSlots,
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) => Completer<Response<dynamic>>().future);

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        tokenStorage: TestTokenStorage(),
        child: const BookingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futsal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(8));
  });
}
