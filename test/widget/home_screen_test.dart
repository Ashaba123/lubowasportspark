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
    await tester.pump();

    expect(find.text('Play • Train • Compete'), findsOneWidget);
    await tester.ensureVisible(find.text('Sports • Fitness • Community'));
    expect(find.text('Sports • Fitness • Community'), findsOneWidget);
    await tester.ensureVisible(find.text('Events'));
    expect(find.text('Events'), findsOneWidget);
    await tester.ensureVisible(find.text('League'));
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

    await tester.ensureVisible(find.text('Events'));
    await tester.tap(find.text('Events'));
    await tester.pump();

    expect(tab, 1);
  });
}
