import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/edition/edition.dart';
import '../../core/network/api_exception.dart';

final appApiRepositoryProvider = Provider<AppApiRepository>((ref) {
  return AppApiRepository(baseUrl: ref.watch(editionProvider).site);
});

class AppApiRepository {
  AppApiRepository({Dio? dio, required String baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                responseType: ResponseType.plain,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<void> saveProfile({required String name, required String email, required String photo, required String token}) =>
      _post('/wp-json/wood-panel-app/v1/profile', {'name':name,'email':email,'photo':photo,'token':token});

  Future<void> subscribeNewsletter({
    required String email,
    String? name,
    String? country,
  }) async {
    await _post('/wp-json/wood-panel-app/v1/newsletter', {
      'email': email,
      'name': name ?? '',
      'country': country ?? '',
    });
  }

  Future<void> sendContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await _post('/wp-json/wood-panel-app/v1/contact', {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      final raw = response.data;
      final body = raw is String
          ? jsonDecode(raw.replaceFirst('\uFEFF', '').trim())
              as Map<String, dynamic>
          : raw as Map<String, dynamic>? ?? const {};
      if (body['success'] != true) {
        throw ApiException((body['message'] as String?) ?? 'Request failed.');
      }
    } on DioException catch (error) {
      throw ApiException(
        error.response?.data is Map<String, dynamic>
            ? ((error.response?.data as Map<String, dynamic>)['message']
                    as String? ??
                'Request failed.')
            : (error.message ?? 'Network request failed.'),
        statusCode: error.response?.statusCode,
      );
    }
  }
}
