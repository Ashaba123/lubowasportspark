import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/features/league/league_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
  });

  testWidgets('LeagueScreen shows Leagues app bar and public view by code', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const LeagueScreen(),
      ),
    );

    expect(find.text('Leagues'), findsOneWidget);
    expect(find.text('Public league stats'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('LeagueScreen enter code and tap View does not crash', (WidgetTester tester) async {
    when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => responseOk<Map<String, dynamic>>({
        'league': {'id': 1, 'name': 'Test League', 'code': 'ABC'},
        'standings': [],
        'fixtures': [],
        'top_scorers': [],
      }),
    );

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const LeagueScreen(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Leagues'), findsOneWidget);
  });
}
