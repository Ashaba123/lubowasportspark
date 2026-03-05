import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lubowa_sports_park/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows tagline and action cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: HomeScreen(onNavigateToTab: (_) {}),
      ),
    );

    // Advance past all FadeSlideIn delays (max 450 ms) then settle animations.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Play • Train • Compete'), findsOneWidget);
    expect(find.text('Sports • Fitness • Community'), findsOneWidget);
    // Action cards
    expect(find.text('Events'), findsOneWidget);
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

    // Wait for cards to animate in before tapping.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events'));
    await tester.pump();

    expect(tab, 1);
  });
}
