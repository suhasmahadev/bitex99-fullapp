import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../models/models.dart';

/// Replaces Firestore restaurant streams and writes.
class RestaurantService {
  final Dio _dio = apiClient.client;

  Map<String, dynamic> _objectPayload(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  // Replaces: DatabaseService.getRestaurantsByTown() Firestore stream
  // Callers: use FutureBuilder + Timer.periodic(30s) for refresh
  Future<List<RestaurantModel>> getRestaurantsByTown(String town) async {
    final response = await _dio.get(
      ApiConstants.restaurants,
      queryParameters: {
        'town': town,
        'status': 'active',
      },
    );
    final List restaurants = response.data['restaurants'] ?? [];
    return restaurants.map((r) => RestaurantModel.fromJson(r)).toList();
  }

  Future<RestaurantModel?> getRestaurantById(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.restaurants}/$id');
      return RestaurantModel.fromJson(_objectPayload(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // Replaces: Firestore stream for restaurant status — poll with Timer.periodic
  Future<RestaurantModel?> getRestaurantStream(String restaurantId) async {
    return getRestaurantById(restaurantId);
  }

  Future<RestaurantModel> registerRestaurant(
      Map<String, dynamic> data) async {
    final response = await _dio.post(
      ApiConstants.restaurants,
      data: data,
    );
    return RestaurantModel.fromJson(_objectPayload(response.data));
  }

  Future<void> toggleOnlineStatus(
      String restaurantId, bool isOpen) async {
    await _dio.put(
      '${ApiConstants.restaurants}/$restaurantId/online-status',
      data: {'isOpen': isOpen},
    );
  }

  Future<void> updateRestaurantStatus(
    String restaurantId,
    String status, {
    String? rejectionReason,
  }) async {
    await _dio.put(
      '${ApiConstants.restaurants}/$restaurantId/status',
      data: {
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      },
    );
  }

  Future<List<RestaurantModel>> getPendingRestaurants() async {
    final response = await _dio.get(
      '${ApiConstants.adminRestaurants}/pending',
    );
    final List list = response.data['restaurants'] ?? response.data['data'] ?? [];
    return list.map((r) => RestaurantModel.fromJson(r)).toList();
  }
}
