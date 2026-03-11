import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/features/events/models/wp_post.dart';

/// Fetches events (WordPress posts) from wp/v2/posts. Public, no auth.
class EventsRepository {
  EventsRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  /// GET wp/v2/posts with _embed for featured image. [page] 1-based.
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<List<WpPost>> getPosts({int perPage = 20, int page = 1, bool forceRefresh = false}) async {
    final response = await _dio.get<List<dynamic>>(
      AppConstants.pathPosts,
      queryParameters: {
        'per_page': perPage,
        'page': page,
        '_embed': true,
      },
      options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
    );
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => WpPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET wp/v2/posts/{id} with _embed.
  /// [forceRefresh] when true passes dio_cache_force_refresh so cache is bypassed.
  Future<WpPost?> getPost(int id, {bool forceRefresh = false}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.pathPosts}/$id',
        queryParameters: {'_embed': true},
        options: forceRefresh ? Options(extra: {'dio_cache_force_refresh': true}) : null,
      );
      final data = response.data;
      return data != null ? WpPost.fromJson(data) : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
