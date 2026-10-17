import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/features/home/home_screen.dart';
import 'package:lubowa_sports_park/shared/skeleton.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  testWidgets('HomeScreen shows tagline and action cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: HomeScreen(onNavigateToTab: (_) {}),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Sports • Fitness • Community'), 100);
    expect(find.text('Sports • Fitness • Community'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Events'), 100);
    expect(find.text('Events'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('League'), 100);
    expect(find.text('League'), findsOneWidget);
  });

  testWidgets('HomeScreen tap on Events triggers onNavigateToTab(1)', (WidgetTester tester) async {
    int? tab;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: HomeScreen(onNavigateToTab: (i) => tab = i),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Events'), 100);
    // Scroll again so Events card is inside 600px viewport (widget was at y=621)
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events'));
    await tester.pump();

    expect(tab, 1);
  });

  testWidgets('HomeScreen View button shimmers while league code loads', (WidgetTester tester) async {
    mockConnectivityOnline();
    final mockDio = MockDio();
    when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenAnswer((_) => Completer<Response<Map<String, dynamic>>>().future);

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: HomeScreen(onNavigateToTab: (_) {}),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('View'), 100);
    await tester.enterText(find.byType(TextField).first, 'L755V9');
    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading…'), findsOneWidget);
    final shimmer = tester.widget<ButtonShimmer>(
      find.ancestor(of: find.text('Loading…'), matching: find.byType(ButtonShimmer)),
    );
    expect(shimmer.active, isTrue);
  });
}
