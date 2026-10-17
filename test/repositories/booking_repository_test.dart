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
    test('submit calls POST /lubowa-ea/v1/bookings with request body', () async {
      const request = BookingRequest(
        serviceId: 3,
        date: '2025-03-15',
        time: '14:00',
        contactName: 'Jane',
        contactPhone: '+256700000',
        notes: 'Pitch A',
      );
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => response201({
                'id': 1,
                'date': '2025-03-15',
                'time_slot': '14:00',
                'contact_name': 'Jane',
                'status': 'pending',
              }));

      final item = await repository.submit(request);

      expect(item.id, 1);
      expect(item.status, 'pending');
      verify(() => mockDio.post<Map<String, dynamic>>(
            AppConstants.pathEaBookings,
            data: request.toJson(),
          )).called(1);
    });

    test('submit throws SlotTakenException on 409 slot_taken', () async {
      final options = RequestOptions(path: AppConstants.pathEaBookings);
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 409,
          data: {
            'code': 'slot_taken',
            'message': 'That time is no longer available.',
            'data': {'status': 409, 'dates': ['2025-03-15']},
          },
        ),
      ));

      expect(
        () => repository.submit(const BookingRequest(
          serviceId: 3,
          date: '2025-03-15',
          time: '14:00',
          contactName: 'A',
          contactPhone: 'B',
        )),
        throwsA(isA<SlotTakenException>().having((e) => e.dates, 'dates', ['2025-03-15'])),
      );
    });

    test('getSlots parses available, booked and unavailable', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => responseOk<dynamic>({
                'date': '2025-03-15',
                'service_id': 3,
                'slots': [
                  {'time': '09:00', 'status': 'unavailable'},
                  {'time': '10:00', 'status': 'booked'},
                  {'time': '11:00', 'status': 'available'},
                ],
              }));

      final slots = await repository.getSlots(serviceId: 3, date: '2025-03-15');

      expect(slots.map((s) => s.status), [SlotStatus.unavailable, SlotStatus.booked, SlotStatus.available]);
      expect(slots.where((s) => s.isAvailable).map((s) => s.time), ['11:00']);
    });

    test('getSlots parses held and mine; mine is selectable, held is not', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => responseOk<dynamic>({
                'slots': [
                  {'time': '16:00', 'status': 'held'},
                  {'time': '17:00', 'status': 'mine'},
                ],
              }));

      final slots = await repository.getSlots(serviceId: 3, date: '2025-03-15', deviceId: 'abc');

      expect(slots.map((s) => s.status), [SlotStatus.held, SlotStatus.mine]);
      expect(slots.where((s) => s.isAvailable).map((s) => s.time), ['17:00']);
      verify(() => mockDio.get<dynamic>(
            AppConstants.pathEaSlots,
            queryParameters: {'service_id': 3, 'date': '2025-03-15', 'device_id': 'abc'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('hold posts the slot and reads expires_in', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => response201({'expires_in': 300}));

      final hold = await repository.hold(deviceId: 'abc', serviceId: 3, date: '2025-03-15', time: '17:00');

      expect(hold.expiresIn, const Duration(minutes: 5));
      verify(() => mockDio.post<Map<String, dynamic>>(
            AppConstants.pathEaHolds,
            data: {'device_id': 'abc', 'service_id': 3, 'date': '2025-03-15', 'time': '17:00'},
          )).called(1);
    });

    test('hold throws SlotTakenException when someone else holds the slot', () async {
      final options = RequestOptions(path: AppConstants.pathEaHolds);
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 409,
          data: {'code': 'slot_taken', 'data': {'status': 409, 'dates': []}},
        ),
      ));

      expect(
        () => repository.hold(deviceId: 'abc', serviceId: 3, date: '2025-03-15', time: '17:00'),
        throwsA(isA<SlotTakenException>()),
      );
    });

    test('getGuestBookings skips the request with no tokens and parses guest_token', () async {
      expect(await repository.getGuestBookings(const []), isEmpty);
      verifyNever(() => mockDio.get<dynamic>(any(),
          queryParameters: any(named: 'queryParameters'), options: any(named: 'options')));

      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => responseOk<dynamic>({
                'data': [
                  {'id': 9, 'date': '2025-03-15', 'time_slot': '17:00', 'status': 'pending', 'guest_token': 't1'},
                ],
              }));

      final list = await repository.getGuestBookings(const ['t1', 't2']);

      expect(list.single.guestToken, 't1');
      verify(() => mockDio.get<dynamic>(
            AppConstants.pathEaGuestBookings,
            queryParameters: {'tokens': 't1,t2'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('getMine reads data list from GET /lubowa-ea/v1/bookings', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => responseOk<dynamic>({
                'data': [
                  {'id': 7, 'date': '2025-03-15', 'time_slot': '10:00', 'contact_name': 'A', 'status': 'approved'},
                ],
              }));

      final list = await repository.getMine();

      expect(list.single.id, 7);
      expect(list.single.status, 'approved');
    });
  });
}
