import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_storage.dart';
import '../core/token_storage.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

final authProvider =
    AsyncNotifierProvider<AuthController, UserModel?>(AuthController.new);

class AuthController extends AsyncNotifier<UserModel?> {
  final _service = AuthService();

  @override
  Future<UserModel?> build() async {
    final cached = LocalStorage.cachedUser;
    if (cached != null) {
      state = AsyncData(UserModel.fromJson(cached));
    }

    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      await LocalStorage.auth.delete('user');
      await LocalStorage.auth.delete('user_json');
      return null;
    }

    try {
      final user = await _service.fetchMe();
      await LocalStorage.cacheUser(user.toJson());
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await TokenStorage.clearAll();
        await LocalStorage.auth.delete('user');
        return null;
      }
      return state.valueOrNull;
    }
  }

  Future<void> login({
    required String phone,
    required String otp,
    required String role,
    String? name,
    String? town,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _service.signInWithOtp(
        phone: phone,
        otp: otp,
        role: role,
        name: name,
        town: town,
      );
      await LocalStorage.cacheUser(user.toJson());
      await LocalStorage.auth.put('user_json', jsonEncode(user.toJson()));
      return user;
    });
  }

  Future<void> logout() async {
    await _service.signOut();
    await LocalStorage.auth.clear();
    state = const AsyncData(null);
  }
}
