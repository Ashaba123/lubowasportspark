import 'dart:async';

import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

/// Bookings via POST/GET /lubowa/v1/bookings. No auth for submit; list by contact_email.
class BookingRepository {
  BookingRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  /// POST /lubowa/v1/bookings. Returns created booking or throws.
  Future<BookingSubmitResponse> submit(BookingRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.pathLubowaBookings,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) throw DioException(requestOptions: response.requestOptions, message: 'Empty response');
    return BookingSubmitResponse.fromJson(data);
  }

  /// GET /lubowa/v1/bookings/slots?date=...&service=... — returns list of { time_slot, status } for that date+service.
  /// Slots with status pending or approved are considered taken.
  Future<List<String>> getBookedSlots(String date, String service) async {
    final response = await _dio.get<dynamic>(
      '${AppConstants.pathLubowaBookings}/slots',
      queryParameters: {'date': date, 'service': service},
    );
    final raw = response.data;
    if (raw is! List || raw.isEmpty) return [];
    final taken = <String>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        final status = e['status'] as String?;
        if (status == 'pending' || status == 'approved') {
          final slot = e['time_slot'] as String?;
          if (slot != null && slot.isNotEmpty) taken.add(slot);
        }
      }
    }
    return taken;
  }

  /// GET /lubowa/v1/bookings?contact_email=... — list bookings (paginated: response has data + meta).
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed (e.g. after creating a booking).
  Future<List<BookingItem>> getByEmail(String contactEmail, {bool forceRefresh = false}) async {
    if (contactEmail.trim().isEmpty) return [];
    final response = await _dio.get<dynamic>(
      AppConstants.pathLubowaBookings,
      queryParameters: {
        'contact_email': contactEmail.trim(),
        'per_page': 100,
        'sort': '-created_at',
      },
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    final raw = response.data;
    if (raw == null) return [];
    final list = _listFromPaginated(raw);
    return list.map((e) => BookingItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poll bookings for a given [contactEmail] every [interval] and emit updates as a stream.
  /// Uses [getByEmail] with `forceRefresh: true` so Dio's cache is bypassed on each tick.
  Stream<List<BookingItem>> getBookingsStream(
    String contactEmail, {
    Duration interval = const Duration(seconds: 3),
  }) async* {
    final email = contactEmail.trim();
    if (email.isEmpty) {
      yield const <BookingItem>[];
      return;
    }
    yield* _poll<List<BookingItem>>(
      () => getByEmail(email, forceRefresh: true),
      interval,
    );
  }

  Stream<T> _poll<T>(Future<T> Function() fetch, Duration interval) {
    final controller = StreamController<T>();
    Timer? timer;

    Future<void> tick() async {
      try {
        final value = await fetch();
        if (!controller.isClosed) controller.add(value);
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    controller.onListen = () {
      tick();
      timer = Timer.periodic(interval, (_) => tick());
    };
    controller.onCancel = () {
      timer?.cancel();
      if (!controller.isClosed) {
        controller.close();
      }
    };

    return controller.stream;
  }

  static List<dynamic> _listFromPaginated(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) return raw['data'] as List<dynamic>? ?? [];
    if (raw is List) return raw;
    return [];
  }
}
