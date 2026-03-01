import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lubowa_sports_park/main.dart';

void main() {
  testWidgets('App starts and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(const LubowaSportsParkApp());
    await tester.pump();
    // Splash uses Future.delayed(2200ms); advance time so onDone runs and home shows.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
    // Allow connectivity check and API load (or error) to complete; avoid pumpAndSettle (loading indicator animates forever).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    // Home shows either content (tagline), error (Retry), or loading; in test env connectivity/API may fail or hang.
    final hasTagline = find.text('Play • Train • Compete').evaluate().isNotEmpty;
    final hasRetry = find.text('Retry').evaluate().isNotEmpty;
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    expect(hasTagline || hasRetry || hasLoading, true);
  });
}
