import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';

final appApiRepositoryProvider = Provider<AppApiRepository>((ref) {
  return AppApiRepository();
});

class AppApiRepository {
  AppApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<void> subscribeNewsletter({
    required String email,
    String? name,
  }) async {
    await _post('/api/app/newsletter', {
      'email': email,
      'name': name ?? '',
    });
  }

  Future<void> sendContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await _post('/api/app/contact', {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      final body = response.data ?? const {};
      if (body['success'] != true) {
        throw ApiException((body['message'] as String?) ?? 'Request failed.');
      }
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data is Map<String, dynamic>
            ? ((error.response?.data as Map<String, dynamic>)['message'] as String? ?? 'Request failed.')
            : (error.message ?? 'Network request failed.'),
        statusCode: error.response?.statusCode,
      );
    }
  }
}
