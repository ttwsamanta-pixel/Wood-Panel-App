import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    String baseUrl = AppConfig.wordpressBaseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
      );
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException(
        error.response?.statusMessage ?? error.message ?? 'Network request failed.',
        statusCode: error.response?.statusCode,
      );
    } on Object catch (error) {
      throw ApiException('Unable to parse response: $error');
    }
  }
}
