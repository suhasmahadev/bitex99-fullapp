import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../models/models.dart';

/// Replaces Firestore menu subcollection streams and writes.
class MenuService {
  final Dio _dio = apiClient.client;

  Map<String, dynamic> _objectPayload(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  // Replaces: Firestore stream on menu subcollection
  Future<List<MenuItemModel>> getMenuForRestaurant(
      String restaurantId) async {
    final response = await _dio.get(
      '${ApiConstants.restaurants}/$restaurantId/menu',
    );
    final List menu = response.data['menu'] ?? [];
    return menu.map((m) => MenuItemModel.fromJson(m)).toList();
  }

  Future<MenuItemModel> addMenuItem(
    String restaurantId,
    Map<String, dynamic> menuItem,
  ) async {
    final response = await _dio.post(
      '${ApiConstants.restaurants}/$restaurantId/menu',
      data: menuItem,
    );
    return MenuItemModel.fromJson(_objectPayload(response.data));
  }

  Future<MenuItemModel> updateMenuItem(
    String restaurantId,
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.put(
      '${ApiConstants.restaurants}/$restaurantId/menu/$itemId',
      data: updates,
    );
    return MenuItemModel.fromJson(_objectPayload(response.data));
  }

  Future<void> deleteMenuItem(
    String restaurantId,
    String itemId,
  ) async {
    await _dio.delete(
      '${ApiConstants.restaurants}/$restaurantId/menu/$itemId',
    );
  }
}
