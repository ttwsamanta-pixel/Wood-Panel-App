import 'dart:convert';
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
                responseType: ResponseType.plain,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;
  final _pending = <String, Future<dynamic>>{};

  Dio get dio => _dio;
  String get baseUrl => _dio.options.baseUrl;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final key = '$T:$path:${jsonEncode(queryParameters)}';
    final existing = _pending[key];
    if (existing != null) return existing.then((value) => value as T);
    final request = _get<T>(path, queryParameters: queryParameters);
    final tracked = request.whenComplete(() {
      _pending.remove(key);
    });
    _pending[key] = tracked;
    return tracked;
  }

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is String && T != String) {
        return jsonDecode(data.replaceFirst('\uFEFF', '').trim()) as T;
      }
      return data as T;
    } on DioException catch (error) {
      throw ApiException(
        error.response?.statusMessage ??
            error.message ??
            'Network request failed.',
        statusCode: error.response?.statusCode,
      );
    } on Object catch (error) {
      throw ApiException('Unable to parse response: $error');
    }
  }
}
