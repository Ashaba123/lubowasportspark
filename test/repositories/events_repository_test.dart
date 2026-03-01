import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/events/events_repository.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;
  late EventsRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    repository = EventsRepository(apiClient: createTestApiClient(dio: mockDio));
  });

  group('EventsRepository', () {
    test('getPosts calls GET /wp/v2/posts with per_page, page, _embed', () async {
      when(() => mockDio.get<List<dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => responseOk<List<dynamic>>([]));

      await repository.getPosts(perPage: 20, page: 1);

      verify(() => mockDio.get<List<dynamic>>(
            AppConstants.pathPosts,
            queryParameters: {'per_page': 20, 'page': 1, '_embed': true},
          )).called(1);
    });

    test('getPosts returns parsed WpPost list', () async {
      final json = [
        {
          'id': 1,
          'title': {'rendered': 'Test Event'},
          'content': {'rendered': '<p>Body</p>'},
          'date': '2025-03-01T10:00:00',
        },
      ];
      when(() => mockDio.get<List<dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => responseOk(json));

      final list = await repository.getPosts();

      expect(list.length, 1);
      expect(list.first.id, 1);
      expect(list.first.title, 'Test Event');
      expect(list.first.date, '2025-03-01T10:00:00');
    });

    test('getPost calls GET /wp/v2/posts/{id} with _embed', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => responseOk<Map<String, dynamic>>({
                'id': 42,
                'title': {'rendered': 'One'},
                'content': {'rendered': ''},
                'date': '',
              }));

      await repository.getPost(42);

      verify(() => mockDio.get<Map<String, dynamic>>(
            '${AppConstants.pathPosts}/42',
            queryParameters: {'_embed': true},
          )).called(1);
    });

    test('getPost returns null on 404', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(statusCode: 404, requestOptions: RequestOptions(path: '')),
      ));

      final post = await repository.getPost(999);

      expect(post, isNull);
    });
  });
}
