import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import 'models/wp_post.dart';

/// Fetches events (WordPress posts) from wp/v2/posts. Public, no auth.
class EventsRepository {
  EventsRepository({ApiClient? apiClient})
      : _dio = apiClient?.dio ?? ApiClient(baseUrl: AppConstants.apiBaseUrl).dio;

  final Dio _dio;

  /// GET wp/v2/posts with _embed for featured image. [page] 1-based.
  Future<List<WpPost>> getPosts({int perPage = 20, int page = 1}) async {
    final response = await _dio.get<List<dynamic>>(
      AppConstants.pathPosts,
      queryParameters: {
        'per_page': perPage,
        'page': page,
        '_embed': true,
      },
    );
    final list = response.data;
    if (list == null) return [];
    return list.map((e) => WpPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET wp/v2/posts/{id} with _embed.
  Future<WpPost?> getPost(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.pathPosts}/$id',
        queryParameters: {'_embed': true},
      );
      final data = response.data;
      return data != null ? WpPost.fromJson(data) : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
