import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/league/login_screen.dart';
import 'package:lubowa_sports_park/shared/skeleton.dart';

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

  testWidgets('LoginScreen button shimmers while signing in', (WidgetTester tester) async {
    mockConnectivityOnline();
    final mockDio = MockDio();
    when(() => mockDio.post<Map<String, dynamic>>(AppConstants.pathJwtToken, data: any(named: 'data')))
        .thenAnswer((_) => Completer<Response<Map<String, dynamic>>>().future);

    await tester.pumpWidget(
      wrapWithAppProviders(
        apiClient: createTestApiClient(dio: mockDio),
        child: const LoginScreen(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'user');
    await tester.enterText(find.byType(TextField).at(1), 'pass');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Signing in…'), findsOneWidget);
    expect(tester.widget<ButtonShimmer>(find.byType(ButtonShimmer)).active, isTrue);
  });
}
