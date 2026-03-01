import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/api/pages_repository.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;
  late PagesRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    repository = PagesRepository(apiClient: createTestApiClient(dio: mockDio));
  });

  group('PagesRepository', () {
    test('getPageBySlug calls GET /wp/v2/pages with slug and _embed', () async {
      when(() => mockDio.get<List<dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => responseOk<List<dynamic>>([]));

      await repository.getPageBySlug('home');

      verify(() => mockDio.get<List<dynamic>>(
            AppConstants.pathPages,
            queryParameters: {'slug': 'home', '_embed': true},
          )).called(1);
    });

    test('getPageBySlug returns null for empty slug', () async {
      final page = await repository.getPageBySlug('');
      expect(page, isNull);
      verifyNever(() => mockDio.get<List<dynamic>>(any(), queryParameters: any(named: 'queryParameters')));
    });
  });
}
