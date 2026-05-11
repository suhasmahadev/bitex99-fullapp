import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../models/models.dart';

class OrderService {
  final Dio _dio = apiClient.client;

  String get _apiV1Base =>
      ApiConstants.apiBase.replaceFirst('/api/flutter/v1', '/api/v1');

  String _apiV1(String path) => '$_apiV1Base$path';

  Map<String, dynamic> _objectPayload(dynamic data) {
    if (data is Map<String, dynamic> && data['orders'] is List && (data['orders'] as List).isNotEmpty) {
      return Map<String, dynamic>.from((data['orders'] as List).first as Map);
    }
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<OrderModel> createOrder({
    required String restaurantId,
    required String town,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    required String landmark,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.orders,
        data: {
          'restaurantId': restaurantId,
          'town': town,
          'items': items,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'landmark': landmark,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      return OrderModel.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['detail'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      throw Exception('Unable to place order');
    }
  }

  Future<OrderModel> placeOrder({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.orders,
        data: {
          'delivery_address_id': addressId,
          'payment_method': paymentMethod,
          if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        },
      );
      return OrderModel.fromJson(_objectPayload(response.data));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw Exception(data['message'] ?? data['detail'] ?? 'Unable to place order');
      }
      throw Exception('Unable to place order');
    }
  }

  Future<List<OrderModel>> getOrders() async {
    final response = await _dio.get(ApiConstants.orders);
    final List orders = response.data['orders'] ?? response.data['data'] ?? [];
    return orders.map((o) => OrderModel.fromJson(o)).toList();
  }

  Future<OrderModel> cancelOrder(String id, String reason) async {
    final response = await _dio.post(
      '${ApiConstants.orders}/$id/cancel',
      data: {'reason': reason},
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<OrderModel?> getOrder(String orderId) async {
    final response = await _dio.get(
      '${ApiConstants.orders}/$orderId',
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<List<OrderModel>> getOrdersForRestaurant(
    String restaurantId, {
    String? status,
  }) async {
    final response = await _dio.get(
      ApiConstants.orders,
      queryParameters: {
        'restaurantId': restaurantId,
        if (status != null) 'status': status,
      },
    );
    final List orders = response.data['orders'] ?? response.data['data'] ?? [];
    return orders.map((o) => OrderModel.fromJson(o)).toList();
  }

  Future<List<OrderModel>> getAvailableOrders(
    String town
  ) async {
    final response = await _dio.get(
      ApiConstants.orders,
      queryParameters: {
        'town': town,
        'status': 'pickup_ready',
        'agentId': 'null',
      },
    );
    final List orders = response.data['orders'] ?? response.data['data'] ?? [];
    return orders.map((o) => OrderModel.fromJson(o)).toList();
  }

  Future<OrderModel> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await _dio.put(
      '${ApiConstants.orders}/$orderId/status',
      data: {'status': status},
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<OrderModel> acceptRestaurantOrder(
    String orderId, {
    required int preparationTime,
  }) async {
    final response = await _dio.post(
      _apiV1('/restaurant/orders/$orderId/accept'),
      data: {'preparation_time': preparationTime},
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<OrderModel> rejectRestaurantOrder(String orderId) async {
    final response = await _dio.post(
      _apiV1('/restaurant/orders/$orderId/reject'),
      data: {
        'reason': 'OTHER',
        'description': 'Rejected by restaurant',
      },
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<OrderModel> markRestaurantPreparing(String orderId) async {
    final response = await _dio.post(_apiV1('/restaurant/orders/$orderId/preparing'));
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<OrderModel> markRestaurantReady(String orderId) async {
    final response = await _dio.post(_apiV1('/restaurant/orders/$orderId/ready'));
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> acceptAssignment(String assignmentId) async {
    final response = await _dio.post(_apiV1('/partner/assignments/$assignmentId/accept'));
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> rejectAssignment(
    String assignmentId, {
    String? reason,
  }) async {
    final response = await _dio.post(
      _apiV1('/partner/assignments/$assignmentId/reject'),
      data: {if (reason != null) 'reason': reason},
    );
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> reachedRestaurant(String assignmentId) async {
    final response = await _dio.post(
      _apiV1('/partner/assignments/$assignmentId/reached-restaurant'),
    );
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> pickedUp(String assignmentId) async {
    final response = await _dio.post(_apiV1('/partner/assignments/$assignmentId/picked-up'));
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> reachedCustomer(String assignmentId) async {
    final response = await _dio.post(
      _apiV1('/partner/assignments/$assignmentId/reached-customer'),
    );
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> deliverAssignment(
    String assignmentId, {
    required String otp,
  }) async {
    final response = await _dio.post(
      _apiV1('/partner/assignments/$assignmentId/deliver'),
      data: {'otp': otp},
    );
    return Map<String, dynamic>.from(_objectPayload(response.data));
  }

  Future<OrderModel> acceptOrder(
    String orderId,
    String agentId,
  ) async {
    final response = await _dio.put(
      '${ApiConstants.orders}/$orderId/agent',
      data: {'agentId': agentId, 'status': 'delivering'},
    );
    return OrderModel.fromJson(_objectPayload(response.data));
  }

  Future<Map<String, dynamic>> completeDelivery({
    required String orderId,
    required String deliveredOtp,
    required String agentId,
  }) async {
    final response = await _dio.put(
      '${ApiConstants.orders}/$orderId/complete',
      data: {
        'deliveredOtp': deliveredOtp,
        'agentId': agentId,
      },
    );
    return response.data;
  }
}
