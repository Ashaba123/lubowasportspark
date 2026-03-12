import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/features/league/league_repository.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';
import 'package:lubowa_sports_park/features/league/team_detail_screen.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;
  late LeagueRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    repository = LeagueRepository(apiClient: createTestApiClient(dio: mockDio));
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'Updating goals in PlayerView and going back refreshes TeamDetail player row',
      (WidgetTester tester) async {
    int playersFetchCount = 0;
    when(() => mockDio.get<dynamic>(
          '/lubowa/v1/teams/10/players',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((Invocation inv) async {
      playersFetchCount += 1;
      final int goals = playersFetchCount == 1 ? 0 : 1;
      return responseOk<dynamic>({
        'data': [
          {
            'id': 20,
            'name': 'Peter',
            'goals': goals,
            'user_id': null,
            'team_id': 10,
          }
        ],
        'meta': {'page': 1, 'per_page': 100, 'total': 1}
      });
    });
    when(() => mockDio.patch<Map<String, dynamic>>(
          '/lubowa/v1/players/20',
          data: any(named: 'data'),
        )).thenAnswer((_) async => responseOk<Map<String, dynamic>>({
          'id': 20,
          'name': 'Peter',
          'goals': 1,
          'user_id': null,
          'team_id': 10,
        }));

    await tester.pumpWidget(
      MaterialApp(
        home: TeamDetailScreen(
          league: const LeagueModel(id: 1, name: 'League', code: 'L1'),
          team: const TeamModel(id: 10, name: 'Vipers'),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 goals'), findsOneWidget);
    await tester.tap(find.text('Peter'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add goals'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 goals'), findsOneWidget);
    verify(() => mockDio.patch<Map<String, dynamic>>(
          '/lubowa/v1/players/20',
          data: {'goals': 1},
        )).called(1);
  });
}
