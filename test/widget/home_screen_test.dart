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

    expect(find.text('Play • Train • Compete'), findsOneWidget);
    expect(find.text('Sports • Fitness • Community'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Hours'), findsOneWidget);
  });

  testWidgets('HomeScreen tap on Events triggers onNavigateToTab(1)', (WidgetTester tester) async {
    int? tab;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: HomeScreen(onNavigateToTab: (i) => tab = i),
      ),
    );

    await tester.tap(find.text('Events'));
    await tester.pump();

    expect(tab, 1);
  });
}
