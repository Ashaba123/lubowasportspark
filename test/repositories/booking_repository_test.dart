import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

import '../helpers/test_api_helpers.dart';

void main() {
  late MockDio mockDio;
  late BookingRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    repository = BookingRepository(apiClient: createTestApiClient(dio: mockDio));
  });

  group('BookingRepository', () {
    test('submit calls POST /lubowa/v1/bookings with request body', () async {
      const request = BookingRequest(
        date: '2025-03-15',
        timeSlot: '14:00',
        contactName: 'Jane',
        contactPhone: '+256700000',
        contactEmail: 'jane@test.com',
        notes: 'Pitch A',
      );
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => response201({'id': 1, 'status': 'pending'}));

      await repository.submit(request);

      verify(() => mockDio.post<Map<String, dynamic>>(
            AppConstants.pathLubowaBookings,
            data: request.toJson(),
          )).called(1);
    });

    test('submit returns BookingSubmitResponse', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => response201({'id': 99, 'status': 'pending'}));

      final resp = await repository.submit(const BookingRequest(
        date: '2025-03-15',
        timeSlot: '14:00',
        contactName: 'A',
        contactPhone: 'B',
        contactEmail: 'c@d.e',
      ));

      expect(resp.id, 99);
      expect(resp.status, 'pending');
    });

    test('getByEmail calls GET /lubowa/v1/bookings with contact_email', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => responseOk<dynamic>({'data': [], 'meta': {'page': 1, 'per_page': 20, 'total': 0}}));

      await repository.getByEmail('user@example.com');

      verify(() => mockDio.get<dynamic>(
            AppConstants.pathLubowaBookings,
            queryParameters: {
              'contact_email': 'user@example.com',
              'per_page': 100,
              'sort': '-created_at',
            },
          )).called(1);
    });

    test('getByEmail returns empty list for empty email', () async {
      final list = await repository.getByEmail('  ');
      expect(list, isEmpty);
      verifyNever(() => mockDio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')));
    });
  });
}
