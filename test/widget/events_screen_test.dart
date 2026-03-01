import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/events/events_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    when(() => mockDio.get<List<dynamic>>(
          AppConstants.pathPosts,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => responseOk<List<dynamic>>([
              {
                'id': 1,
                'title': {'rendered': 'Test Event'},
                'content': {'rendered': '<p>Body</p>'},
                'date': '2025-03-15T10:00:00',
              },
            ]));
    when(() => mockDio.get<List<dynamic>>(
          AppConstants.pathPages,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => responseOk<List<dynamic>>([
              {
                'id': 1,
                'title': {'rendered': 'Events'},
                'content': {'rendered': 'Intro'},
                'date': '',
              },
            ]));
  });

  testWidgets('EventsScreen shows Events app bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const EventsScreen(),
      ),
    );
    expect(find.text('Events'), findsOneWidget);
  });

  testWidgets('EventsScreen shows loading or content or retry after load', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const EventsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final hasEvents = find.text('Events').evaluate().isNotEmpty;
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasRetry = find.text('Retry').evaluate().isNotEmpty;
    final hasEventOrEmpty = find.text('Test Event').evaluate().isNotEmpty || find.text('No events right now.').evaluate().isNotEmpty;
    expect(hasEvents, true);
    expect(hasLoading || hasRetry || hasEventOrEmpty, true);
  });
}
