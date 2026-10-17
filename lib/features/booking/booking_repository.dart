import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

/// Bookings via the Lubowa EA Bridge (/lubowa-ea/v1), backed by Easy!Appointments.
/// Booking is open to guests; only [getMine] and league bookings need JWT login.
class BookingRepository {
  BookingRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  Future<List<BookingService>> getServices() async {
    final response = await _dio.get<dynamic>(AppConstants.pathEaServices);
    final raw = response.data;
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(BookingService.fromJson).toList();
  }

  /// Full grid for the date. Pass [deviceId] so this device's own hold comes back as [SlotStatus.mine].
  Future<List<BookingSlot>> getSlots({required int serviceId, required String date, String? deviceId}) async {
    final response = await _dio.get<dynamic>(
      AppConstants.pathEaSlots,
      queryParameters: {'service_id': serviceId, 'date': date, if (deviceId != null) 'device_id': deviceId},
      options: Options(extra: {'dio_cache_force_refresh': true}),
    );
    final raw = response.data;
    final list = raw is Map ? raw['slots'] : null;
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().map(BookingSlot.fromJson).toList();
  }

  /// Holds the slot for this device (replacing any other hold it has), or extends the hold if it is
  /// the same slot. Throws [SlotTakenException] when someone else has it.
  Future<SlotHold> hold({
    required String deviceId,
    required int serviceId,
    required String date,
    required String time,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.pathEaHolds,
        data: {'device_id': deviceId, 'service_id': serviceId, 'date': date, 'time': time},
      );
      return SlotHold.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw _slotTakenOr(e);
    }
  }

  Future<void> releaseHold(String deviceId) async {
    await _dio.delete<dynamic>(AppConstants.pathEaHolds, queryParameters: {'device_id': deviceId});
  }

  /// Bookings made on this device, by the tokens returned when they were created.
  Future<List<BookingItem>> getGuestBookings(List<String> tokens) async {
    if (tokens.isEmpty) return [];
    final response = await _dio.get<dynamic>(
      AppConstants.pathEaGuestBookings,
      queryParameters: {'tokens': tokens.join(',')},
      options: Options(extra: {'dio_cache_force_refresh': true}),
    );
    return _dataList(response.data).whereType<Map<String, dynamic>>().map(BookingItem.fromJson).toList();
  }

  /// Throws [SlotTakenException] when the slot was booked in the meantime.
  Future<BookingItem> submit(BookingRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConstants.pathEaBookings,
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
      return BookingItem.fromJson(data);
    } on DioException catch (e) {
      throw _slotTakenOr(e);
    }
  }

  /// Bookings of the logged-in user.
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after creating a booking).
  Future<List<BookingItem>> getMine({bool forceRefresh = false}) async {
    final response = await _dio.get<dynamic>(
      AppConstants.pathEaBookings,
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    return _dataList(response.data).whereType<Map<String, dynamic>>().map(BookingItem.fromJson).toList();
  }

  Future<List<LeagueBookingSlot>> getLeagueBookings(int leagueId) async {
    final response = await _dio.get<dynamic>(
      AppConstants.pathEaLeagueBookings(leagueId),
      options: Options(extra: {'dio_cache_force_refresh': true}),
    );
    return _dataList(response.data).whereType<Map<String, dynamic>>().map(LeagueBookingSlot.fromJson).toList();
  }

  /// Books the same time weekly for [weeks] weeks. All-or-nothing; throws [SlotTakenException]
  /// listing clashing dates.
  Future<List<LeagueBookingSlot>> bookLeague({
    required int leagueId,
    required int serviceId,
    required String date,
    required String time,
    required int weeks,
    String? contactPhone,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        AppConstants.pathEaLeagueBookings(leagueId),
        data: {
          'service_id': serviceId,
          'date': date,
          'time': time,
          'weeks': weeks,
          if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
        },
      );
      return _dataList(response.data).whereType<Map<String, dynamic>>().map(LeagueBookingSlot.fromJson).toList();
    } on DioException catch (e) {
      throw _slotTakenOr(e);
    }
  }

  static Object _slotTakenOr(DioException e) {
    final body = e.response?.data;
    if (e.response?.statusCode == 409 && body is Map && body['code'] == 'slot_taken') {
      final data = body['data'];
      final dates = data is Map && data['dates'] is List
          ? (data['dates'] as List).map((d) => d.toString()).toList()
          : <String>[];
      return SlotTakenException(dates);
    }
    return e;
  }

  static List<dynamic> _dataList(dynamic raw) {
    if (raw is Map && raw['data'] is List) return raw['data'] as List<dynamic>;
    if (raw is List) return raw;
    return [];
  }
}

String formatBookingDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
