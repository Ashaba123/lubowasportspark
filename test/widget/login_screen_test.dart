import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/features/league/login_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  testWidgets('LoginScreen shows Login app bar and form', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: MockDio()),
        child: const LoginScreen(),
      ),
    );

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Login to manage your league'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('LoginScreen shows Required when submitting empty form', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: MockDio()),
        child: const LoginScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsAtLeast(1));
  });

}
