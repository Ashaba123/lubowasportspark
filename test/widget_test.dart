import 'package:flutter_test/flutter_test.dart';
import 'package:lubowa_sports_park/main.dart';

void main() {
  testWidgets('App starts and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(const LubowaSportsParkApp());
    await tester.pumpAndSettle();
    // Splash uses Future.delayed(2200ms); advance time so onDone runs and home shows.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Play • Train • Compete'), findsOneWidget);
  });
}
