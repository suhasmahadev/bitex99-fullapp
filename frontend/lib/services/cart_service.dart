import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../models/models.dart';

class CartConflictException implements Exception {
  final String existingRestaurant;
  final String newRestaurant;
  final String menuItemId;
  final int quantity;

  CartConflictException({
    required this.existingRestaurant,
    required this.newRestaurant,
    required this.menuItemId,
    required this.quantity,
  });
}

class CartService {
  final Dio _dio = apiClient.client;

  Future<CartState> getCart() async {
    final response = await _dio.get(ApiConstants.cart);
    return CartState.fromJson(response.data);
  }

  Future<CartState> addItem(String menuItemId, int quantity) async {
    try {
      final response = await _dio.post(
        ApiConstants.cartAdd,
        data: {'menu_item_id': menuItemId, 'quantity': quantity},
      );
      return CartState.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map &&
          data['error_code'] == 'CART_CONFLICT') {
        final conflict = data['data'] is Map
            ? Map<String, dynamic>.from(data['data'])
            : <String, dynamic>{};
        final existing = conflict['existing_restaurant'] is Map
            ? Map<String, dynamic>.from(conflict['existing_restaurant'])
            : <String, dynamic>{};
        final next = conflict['new_restaurant'] is Map
            ? Map<String, dynamic>.from(conflict['new_restaurant'])
            : <String, dynamic>{};
        throw CartConflictException(
          existingRestaurant: existing['name']?.toString() ?? 'another restaurant',
          newRestaurant: next['name']?.toString() ?? 'this restaurant',
          menuItemId: menuItemId,
          quantity: quantity,
        );
      }
      rethrow;
    }
  }

  Future<CartState> updateQuantity(String menuItemId, int quantity) async {
    final response = await _dio.post(
      ApiConstants.cartUpdateQuantity,
      data: {'menu_item_id': menuItemId, 'quantity': quantity},
    );
    return CartState.fromJson(response.data);
  }

  Future<CartState> clear() async {
    final response = await _dio.post(ApiConstants.cartClear);
    return CartState.fromJson(response.data);
  }

  Future<CartValidationResult> validate() async {
    final response = await _dio.post(ApiConstants.cartValidate);
    return CartValidationResult.fromJson(response.data);
  }
}
