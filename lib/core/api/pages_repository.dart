import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../models/wp_page.dart';
import 'api_client.dart';

/// Fetches WordPress pages (wp/v2/pages). Used for Home, Activities, About, Contact.
class PagesRepository {
  PagesRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  /// GET wp/v2/pages?slug={slug}&_embed. Returns first match or null.
  Future<WpPage?> getPageBySlug(String slug) async {
    if (slug.isEmpty) return null;
    try {
      final response = await _dio.get<List<dynamic>>(
        AppConstants.pathPages,
        queryParameters: {'slug': slug, '_embed': true},
      );
      final list = response.data;
      if (list == null || list.isEmpty) return null;
      return WpPage.fromJson(list[0] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
