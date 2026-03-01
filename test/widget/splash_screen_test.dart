import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lubowa_sports_park/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen shows logo and title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: SplashScreen(onDone: () {}, duration: const Duration(milliseconds: 10)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Lubowa Sports Park'), findsOneWidget);
  });

  testWidgets('SplashScreen calls onDone after duration', (WidgetTester tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: SplashScreen(
          onDone: () => done = true,
          duration: const Duration(milliseconds: 100),
        ),
      ),
    );

    expect(done, false);
    await tester.pump(const Duration(milliseconds: 150));
    expect(done, true);
  });
}
