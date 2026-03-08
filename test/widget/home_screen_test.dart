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
}
