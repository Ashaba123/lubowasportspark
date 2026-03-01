import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import 'models/booking.dart';

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

  /// GET /lubowa/v1/bookings?contact_email=... — list bookings for contact (optional).
  Future<List<BookingItem>> getByEmail(String contactEmail) async {
    if (contactEmail.trim().isEmpty) return [];
    final response = await _dio.get<List<dynamic>>(
      AppConstants.pathLubowaBookings,
      queryParameters: {'contact_email': contactEmail.trim()},
    );
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => BookingItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
