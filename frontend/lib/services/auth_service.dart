import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/app_exceptions.dart';
import '../core/token_storage.dart';
import '../models/models.dart';

/// Replaces FirebaseAuth completely.
/// All OTP operations now hit the FastAPI backend.
class AuthService {
  final Dio _dio = apiClient.client;

  // ── Send OTP (replaces FirebaseAuth.verifyPhoneNumber) ──────────────────
  Future<void> verifyPhone(String phone) async {
    // Send exactly 10 digits — backend adds +91 internally
    final clean = phone.trim().replaceAll(' ', '');
    try {
      final response = await _dio.post(
        ApiConstants.sendOtp,
        data: {'phone': clean},
      );
      if (response.data['success'] != true) {
        throw ApiException(message: response.data['message'] ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Verify OTP (replaces FirebaseAuth.signInWithCredential) ─────────────
  Future<UserModel> signInWithOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
    String? town,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyOtp,
        data: {
          'phone': phone.trim(),
          'otp': otp,
          'role': role,
          if (name != null && name.isNotEmpty) 'name': name,
          if (town != null && town.isNotEmpty) 'town': town,
        },
      );
      final data = response.data;

      // Persist credentials securely
      await TokenStorage.saveToken(data['token']);
      await TokenStorage.saveRefreshToken(data['refreshToken']);
      await TokenStorage.saveRole(data['user']['role']);
      await TokenStorage.saveUser(jsonEncode(data['user']));

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // ── Sign Out (replaces FirebaseAuth.signOut) ─────────────────────────────
  Future<void> signOut() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {}
    await TokenStorage.clearAll();
  }

  // ── Auth check (replaces FirebaseAuth.currentUser != null) ───────────────
  Future<bool> isLoggedIn() async {
    return TokenStorage.hasToken();
  }

  // ── Get current user from local cache (replaces auth state stream) ───────
  Future<UserModel?> getCurrentUser() async {
    final userJson = await TokenStorage.getUser();
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson));
    } catch (e) {
      debugPrint('AuthService.getCurrentUser parse error: $e');
      return null;
    }
  }

  Future<UserModel> fetchMe() async {
    final response = await _dio.get(ApiConstants.me);
    final data = response.data is Map<String, dynamic> &&
            response.data['user'] is Map<String, dynamic>
        ? response.data['user'] as Map<String, dynamic>
        : response.data as Map<String, dynamic>;
    await TokenStorage.saveUser(jsonEncode(data));
    await TokenStorage.saveRole(data['role']?.toString() ?? 'customer');
    return UserModel.fromJson(data);
  }

  /// PATCH /api/v1/users/me — update name/email (used after Google sign-in pre-fill)
  Future<void> patchProfile({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (body.isEmpty) return;
    try {
      await _dio.patch('/users/me', data: body);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Internal error mapper ─────────────────────────────────────────────────
  void _handleDioError(DioException e) {
    final data = e.response?.data;
    final errorCode = data?['error_code'] ?? '';
    final message = data?['message'] ?? 'Something went wrong';
    final statusCode = e.response?.statusCode;

    if (errorCode == 'OTP_COOLDOWN') {
      throw OtpCooldownException(data?['seconds_remaining'] ?? 60);
    }
    if (errorCode == 'INVALID_OTP') {
      throw InvalidOtpException(data?['attempts_remaining'] ?? 0);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      throw NetworkException();
    }
    throw ApiException(
      message: message,
      errorCode: errorCode,
      statusCode: statusCode,
    );
  }
}
