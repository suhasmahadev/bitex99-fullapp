import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'api_constants.dart';
import 'token_storage.dart';

/// Singleton Dio client with auth interceptor.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  bool _initialized = false;
  bool _refreshing = false;

  void initialize() {
    if (_initialized) return;
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    debugPrint('API connecting to: ${ApiConstants.baseIP}:${ApiConstants.basePort}');

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          debugPrint('Token read error: $e');
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        debugPrint('API Error: $status ${error.requestOptions.path}');

        if (status == 401) {
          // Try refresh token once
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            // Retry original request with new token
            final token = await TokenStorage.getToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {}
          }
          // Refresh failed -> clear storage
          await TokenStorage.clearAll();
          return handler.reject(error);
        }
        // Only show NetworkException for actual connection errors
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          debugPrint('REAL network error: ${error.type}');
        }
        return handler.next(error);
      },
    ));
    _initialized = true;
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return false;
      final response = await Dio(BaseOptions(baseUrl: ApiConstants.apiBase)).post(
        ApiConstants.refresh,
        data: {'refresh_token': refresh},
      );
      final newToken = response.data['access_token'] ?? response.data['token'];
      final newRefresh = response.data['refresh_token'] ?? response.data['refreshToken'];
      if (newToken == null || newRefresh == null) return false;
      await TokenStorage.saveToken(newToken);
      await TokenStorage.saveRefreshToken(newRefresh);
      return true;
    } catch (e) {
      debugPrint('Refresh failed: $e');
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Dio get client {
    if (!_initialized) initialize();
    return _dio;
  }
}

final apiClient = ApiClient();
