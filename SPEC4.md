════════════════════════════════════════════════════════
SPEC4.md — Flutter Frontend ↔ FastAPI Backend Integration
BiteX99 — Complete Firebase Removal + Backend Connection
════════════════════════════════════════════════════════

DOCUMENT PURPOSE:
  Remove every Firebase dependency from the Flutter app.
  Connect all screens directly to the FastAPI backend.
  No structural or UI changes. No design changes.
  Only service layer, API calls, and data models change.

READ BEFORE ANYTHING:
  Backend base URL (development):
    http://{YOUR_MACHINE_IP}:8000/api/flutter/v1
  Backend runs on: FastAPI + PostgreSQL + Redis
  Auth: Custom OTP + JWT (NOT Firebase)
  Real-time: HTTP polling every 5s (NOT Firestore streams)
  File upload: Multipart to backend (NOT Firebase Storage)

════════════════════════════════════════════════════════
SECTION 1 — COMPLETE DEPENDENCY AUDIT
════════════════════════════════════════════════════════

REMOVE from pubspec.yaml — every Firebase package:
  firebase_core
  firebase_auth
  cloud_firestore
  firebase_storage
  firebase_messaging (keep if used for push, else remove)
  firebase_analytics (remove)
  google_sign_in (remove)

ADD to pubspec.yaml:
  http: ^1.2.0                  ← REST API calls
  dio: ^5.4.0                   ← advanced HTTP, interceptors
  flutter_secure_storage: ^9.0.0 ← store JWT token securely
  shared_preferences: ^2.2.0    ← store non-sensitive prefs
  web_socket_channel: ^2.4.0   ← WebSocket for order tracking
  image_picker: ^1.0.7          ← already exists, keep
  intl: ^0.19.0                 ← date formatting

REMOVE from AndroidManifest.xml:
  google-services.json reference
  Firebase metadata tags

REMOVE from ios/Runner:
  GoogleService-Info.plist
  Firebase pod references in Podfile

════════════════════════════════════════════════════════
SECTION 2 — NEW FILE STRUCTURE
════════════════════════════════════════════════════════

Create these new files. Do NOT delete existing screen files.

lib/
├── core/
│   ├── api_client.dart          ← Dio instance + interceptors
│   ├── api_constants.dart       ← all endpoint URLs
│   ├── token_storage.dart       ← secure JWT storage
│   └── app_exceptions.dart      ← typed API errors
│
├── services/
│   ├── auth_service.dart        ← REPLACE Firebase Auth
│   ├── user_service.dart        ← user profile CRUD
│   ├── restaurant_service.dart  ← REPLACE Firestore restaurant
│   ├── menu_service.dart        ← REPLACE Firestore menu
│   ├── order_service.dart       ← REPLACE Firestore orders
│   ├── agent_service.dart       ← REPLACE Firestore agent KYC
│   ├── upload_service.dart      ← REPLACE Firebase Storage
│   └── admin_service.dart       ← REPLACE Firestore admin
│
├── models/
│   ├── user_model.dart          ← UPDATE (remove Firebase refs)
│   ├── restaurant_model.dart    ← UPDATE
│   ├── menu_item_model.dart     ← UPDATE
│   ├── order_model.dart         ← UPDATE
│   └── agent_kyc_model.dart     ← UPDATE
│
└── providers/
    └── auth_provider.dart       ← UPDATE (remove Firebase)

════════════════════════════════════════════════════════
SECTION 3 — API CLIENT (CORE)
════════════════════════════════════════════════════════

lib/core/api_constants.dart:

  class ApiConstants {
    // CHANGE THIS to your machine IP before running
    static const String baseIP = '192.168.1.105';
    static const String basePort = '8000';
    static const String apiBase =
      'http://$baseIP:$basePort/api/flutter/v1';
    static const String wsBase =
      'ws://$baseIP:$basePort/api/v1/ws';
    static const String uploadBase =
      'http://$baseIP:$basePort/uploads';

    // Auth
    static const String sendOtp = '/auth/send-otp';
    static const String verifyOtp = '/auth/verify-otp';
    static const String logout = '/auth/logout';

    // Users
    static const String userProfile = '/users';

    // Restaurants
    static const String restaurants = '/restaurants';

    // Orders
    static const String orders = '/orders';

    // Agents
    static const String agentKyc = '/agents/kyc';
    static const String agentKycStatus = '/agents';

    // Admin
    static const String adminRestaurants =
      '/admin/restaurants';
    static const String adminAgents = '/admin/agents';

    // Upload
    static const String upload = '/upload/image';

    // Config
    static const String config = '/config';
  }

lib/core/token_storage.dart:

  import 'package:flutter_secure_storage/flutter_secure_storage.dart';

  class TokenStorage {
    static const _storage = FlutterSecureStorage();
    static const _tokenKey = 'bitex_token';
    static const _userKey = 'bitex_user';
    static const _roleKey = 'bitex_role';

    static Future<void> saveToken(String token) async {
      await _storage.write(key: _tokenKey, value: token);
    }

    static Future<String?> getToken() async {
      return await _storage.read(key: _tokenKey);
    }

    static Future<void> saveUser(String userJson) async {
      await _storage.write(key: _userKey, value: userJson);
    }

    static Future<String?> getUser() async {
      return await _storage.read(key: _userKey);
    }

    static Future<void> saveRole(String role) async {
      await _storage.write(key: _roleKey, value: role);
    }

    static Future<String?> getRole() async {
      return await _storage.read(key: _roleKey);
    }

    static Future<void> clearAll() async {
      await _storage.deleteAll();
    }

    static Future<bool> hasToken() async {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    }
  }

lib/core/api_client.dart:

  import 'package:dio/dio.dart';
  import 'token_storage.dart';
  import 'api_constants.dart';

  class ApiClient {
    static final ApiClient _instance = ApiClient._internal();
    factory ApiClient() => _instance;
    ApiClient._internal();

    late final Dio dio;

    void initialize() {
      dio = Dio(BaseOptions(
        baseUrl: ApiConstants.apiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));

      // Auth interceptor — attach token to every request
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // 401 → clear storage → trigger re-login
          if (error.response?.statusCode == 401) {
            await TokenStorage.clearAll();
            // Navigate to login
            // Use your navigation service here
          }
          return handler.next(error);
        },
      ));
    }

    Dio get client => dio;
  }

  // Global instance
  final apiClient = ApiClient();

lib/core/app_exceptions.dart:

  class ApiException implements Exception {
    final String message;
    final String? errorCode;
    final int? statusCode;

    ApiException({
      required this.message,
      this.errorCode,
      this.statusCode,
    });

    @override
    String toString() => message;
  }

  class OtpCooldownException extends ApiException {
    final int secondsRemaining;
    OtpCooldownException(this.secondsRemaining)
      : super(message: 'Wait ${secondsRemaining}s before resending',
               errorCode: 'OTP_COOLDOWN');
  }

  class InvalidOtpException extends ApiException {
    final int attemptsRemaining;
    InvalidOtpException(this.attemptsRemaining)
      : super(message: 'Invalid OTP. $attemptsRemaining attempts left',
               errorCode: 'INVALID_OTP');
  }

  class NetworkException extends ApiException {
    NetworkException()
      : super(message: 'No internet connection. Please try again.');
  }

════════════════════════════════════════════════════════
SECTION 4 — UPDATED DATA MODELS
════════════════════════════════════════════════════════

lib/models/user_model.dart:
  REMOVE: any Firebase/Firestore imports
  KEEP: all fields exactly as they are
  ADD: fromJson factory that parses backend response

  class UserModel {
    final String uid;
    final String name;
    final String phone;
    final String role;       // "customer"|"restaurant"|"agent"|"admin"
    final String town;
    final String status;
    final String? kycStatus;        // for agents
    final String? restaurantStatus; // for restaurant partners
    final DateTime? createdAt;

    UserModel({
      required this.uid,
      required this.name,
      required this.phone,
      required this.role,
      required this.town,
      required this.status,
      this.kycStatus,
      this.restaurantStatus,
      this.createdAt,
    });

    factory UserModel.fromJson(Map<String, dynamic> json) {
      return UserModel(
        uid: json['uid']?.toString() ?? '',
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        role: json['role'] ?? 'customer',
        town: json['town'] ?? '',
        status: json['status'] ?? 'active',
        kycStatus: json['kycStatus'],
        restaurantStatus: json['restaurantStatus'],
        createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      );
    }

    Map<String, dynamic> toJson() => {
      'uid': uid, 'name': name, 'phone': phone,
      'role': role, 'town': town, 'status': status,
    };
  }

lib/models/restaurant_model.dart:
  REMOVE: Firestore DocumentSnapshot references
  UPDATE: fromJson to parse backend response

  class RestaurantModel {
    final String id;
    final String shopName;
    final String ownerName;
    final String phone;
    final String email;
    final String town;
    final String address;
    final String cuisineType;
    final String fssaiNumber;
    final String upiId;
    final String status;
    final String fssaiPhotoUrl;
    final String kitchenPhotoUrl;
    final String signboardPhotoUrl;
    final String restaurantImageUrl;
    final bool isOpen;
    final double rating;
    final int totalRatings;
    final double deliveryFee;
    final double minOrderAmount;
    final int avgDeliveryTime;

    // Keep all existing constructors
    // ADD:
    factory RestaurantModel.fromJson(Map<String, dynamic> json) {
      return RestaurantModel(
        id: json['id']?.toString() ?? '',
        shopName: json['shopName'] ?? '',
        ownerName: json['ownerName'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
        town: json['town'] ?? '',
        address: json['address'] ?? '',
        cuisineType: json['cuisineType'] ?? '',
        fssaiNumber: json['fssaiNumber'] ?? '',
        upiId: json['upiId'] ?? '',
        status: json['status'] ?? 'pending',
        fssaiPhotoUrl: json['fssaiPhotoUrl'] ?? '',
        kitchenPhotoUrl: json['kitchenPhotoUrl'] ?? '',
        signboardPhotoUrl: json['signboardPhotoUrl'] ?? '',
        restaurantImageUrl: json['restaurantImageUrl'] ?? '',
        isOpen: json['isOpen'] ?? false,
        rating: (json['rating'] ?? 0.0).toDouble(),
        totalRatings: json['totalRatings'] ?? 0,
        deliveryFee: (json['deliveryFee'] ?? 0.0).toDouble(),
        minOrderAmount: (json['minOrderAmount'] ?? 0.0).toDouble(),
        avgDeliveryTime: json['avgDeliveryTime'] ?? 30,
      );
    }
  }

lib/models/menu_item_model.dart:
  REMOVE: Firestore references
  UPDATE: fromJson factory

  class MenuItemModel {
    final String id;
    final String restaurantId;
    final String name;
    final String description;
    final double price;
    final String category;
    final bool available;
    final String imageUrl;
    final bool isSpecial;
    final int preparationTime;
    final bool isVeg;

    factory MenuItemModel.fromJson(Map<String, dynamic> json) {
      return MenuItemModel(
        id: json['id']?.toString() ?? '',
        restaurantId: json['restaurantId']?.toString() ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: (json['price'] ?? 0.0).toDouble(),
        category: json['category'] ?? '',
        available: json['available'] ?? true,
        imageUrl: json['imageUrl'] ?? '',
        isSpecial: json['isSpecial'] ?? false,
        preparationTime: json['preparationTime'] ?? 15,
        isVeg: json['isVeg'] ?? true,
      );
    }
  }

lib/models/order_model.dart:
  REMOVE: Firestore references
  KEEP: all existing fields
  UPDATE: fromJson — status uses Flutter names

  class OrderModel {
    final String id;
    final String customerId;
    final String restaurantId;
    final String? agentId;
    final String town;
    final List<OrderItemModel> items;
    final double totalAmount;
    final String paymentMethod;  // "upi" | "cash"
    final String landmark;
    final String status;         // Flutter status names
    final String? pickupCode;
    final String? deliveryOtp;
    final DateTime createdAt;
    final DateTime? updatedAt;

    factory OrderModel.fromJson(Map<String, dynamic> json) {
      return OrderModel(
        id: json['id']?.toString() ?? '',
        customerId: json['customerId']?.toString() ?? '',
        restaurantId: json['restaurantId']?.toString() ?? '',
        agentId: json['agentId']?.toString(),
        town: json['town'] ?? '',
        items: (json['items'] as List? ?? [])
          .map((i) => OrderItemModel.fromJson(i))
          .toList(),
        totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
        paymentMethod: json['paymentMethod'] ?? 'cash',
        landmark: json['landmark'] ?? '',
        status: json['status'] ?? 'received',
        pickupCode: json['pickupCode']?.toString(),
        deliveryOtp: json['deliveryOtp']?.toString(),
        createdAt: DateTime.tryParse(
          json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      );
    }
  }

  class OrderItemModel {
    final String itemId;
    final String name;
    final int quantity;
    final double price;
    final double totalPrice;

    factory OrderItemModel.fromJson(Map<String, dynamic> json) {
      return OrderItemModel(
        itemId: json['itemId']?.toString() ?? '',
        name: json['name'] ?? '',
        quantity: json['quantity'] ?? 1,
        price: (json['price'] ?? 0.0).toDouble(),
        totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      );
    }
  }

════════════════════════════════════════════════════════
SECTION 5 — SERVICE LAYER (REPLACE FIREBASE)
════════════════════════════════════════════════════════

lib/services/auth_service.dart:
  REPLACE: FirebaseAuth.instance.verifyPhoneNumber()
  REPLACE: FirebaseAuth.instance.signInWithCredential()
  WITH: HTTP calls to backend OTP endpoints

  class AuthService {
    final Dio _dio = apiClient.client;

    // REPLACES: FirebaseAuth.instance.verifyPhoneNumber()
    Future<void> verifyPhone(String phone) async {
      // Strip spaces, add +91 if needed
      final formatted = _formatPhone(phone);
      try {
        final response = await _dio.post(
          ApiConstants.sendOtp,
          data: {'phone': phone}, // send 10 digits
        );
        if (response.data['success'] != true) {
          throw ApiException(message: response.data['message']);
        }
      } on DioException catch (e) {
        _handleDioError(e);
      }
    }

    // REPLACES: FirebaseAuth.instance.signInWithCredential()
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
            'phone': phone,
            'otp': otp,
            'role': role,
            if (name != null && name.isNotEmpty) 'name': name,
            if (town != null && town.isNotEmpty) 'town': town,
          },
        );
        final data = response.data;

        // Save token securely
        await TokenStorage.saveToken(data['token']);
        await TokenStorage.saveRole(data['user']['role']);
        await TokenStorage.saveUser(
          jsonEncode(data['user']));

        return UserModel.fromJson(data['user']);
      } on DioException catch (e) {
        _handleDioError(e);
        rethrow;
      }
    }

    // REPLACES: FirebaseAuth.instance.signOut()
    Future<void> signOut() async {
      try {
        await _dio.post(ApiConstants.logout);
      } catch (_) {}
      await TokenStorage.clearAll();
    }

    // REPLACES: FirebaseAuth.instance.currentUser check
    Future<bool> isLoggedIn() async {
      return await TokenStorage.hasToken();
    }

    // REPLACES: stream of auth state changes
    Future<UserModel?> getCurrentUser() async {
      final userJson = await TokenStorage.getUser();
      if (userJson == null) return null;
      return UserModel.fromJson(jsonDecode(userJson));
    }

    String _formatPhone(String phone) {
      phone = phone.trim().replaceAll(' ', '');
      if (phone.startsWith('+91')) return phone;
      if (phone.startsWith('91') && phone.length == 12) {
        return '+$phone';
      }
      return '+91$phone';
    }

    void _handleDioError(DioException e) {
      final data = e.response?.data;
      final errorCode = data?['error_code'] ?? '';
      final message = data?['message'] ?? 'Something went wrong';
      final statusCode = e.response?.statusCode;

      if (errorCode == 'OTP_COOLDOWN') {
        throw OtpCooldownException(
          data?['seconds_remaining'] ?? 60);
      }
      if (errorCode == 'INVALID_OTP') {
        throw InvalidOtpException(
          data?['attempts_remaining'] ?? 0);
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException();
      }
      throw ApiException(
        message: message,
        errorCode: errorCode,
        statusCode: statusCode,
      );
    }
  }

lib/services/restaurant_service.dart:
  REPLACE: DatabaseService.getRestaurantsByTown()
           which used Firestore streams
  WITH: HTTP polling

  class RestaurantService {
    final Dio _dio = apiClient.client;

    // REPLACES: Firestore stream
    // Flutter screens that used StreamBuilder need to be
    // updated to use FutureBuilder + periodic refresh
    Future<List<RestaurantModel>> getRestaurantsByTown(
      String town
    ) async {
      final response = await _dio.get(
        ApiConstants.restaurants,
        queryParameters: {
          'town': town,
          'status': 'active',
        },
      );
      final List restaurants = response.data['restaurants'];
      return restaurants
        .map((r) => RestaurantModel.fromJson(r))
        .toList();
    }

    Future<RestaurantModel?> getRestaurantById(
      String id
    ) async {
      final response = await _dio.get(
        '${ApiConstants.restaurants}/$id',
      );
      return RestaurantModel.fromJson(response.data['data']);
    }

    // REPLACES: Firestore stream for restaurant status
    // Use polling with Timer.periodic every 10s
    Future<RestaurantModel?> getRestaurantStream(
      String restaurantId
    ) async {
      return getRestaurantById(restaurantId);
    }

    Future<RestaurantModel> registerRestaurant(
      Map<String, dynamic> data
    ) async {
      final response = await _dio.post(
        ApiConstants.restaurants,
        data: data,
      );
      return RestaurantModel.fromJson(response.data['data']);
    }

    Future<void> toggleOnlineStatus(
      String restaurantId,
      bool isOpen
    ) async {
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
          if (rejectionReason != null)
            'rejectionReason': rejectionReason,
        },
      );
    }

    Future<List<RestaurantModel>> getPendingRestaurants() async {
      final response = await _dio.get(
        '${ApiConstants.adminRestaurants}/pending',
      );
      final List list = response.data['data'] ?? [];
      return list.map((r) => RestaurantModel.fromJson(r)).toList();
    }
  }

lib/services/menu_service.dart:
  REPLACE: Firestore subcollection streams
  WITH: HTTP calls

  class MenuService {
    final Dio _dio = apiClient.client;

    // REPLACES: Firestore stream on menu subcollection
    Future<List<MenuItemModel>> getMenuForRestaurant(
      String restaurantId
    ) async {
      final response = await _dio.get(
        '${ApiConstants.restaurants}/$restaurantId/menu',
      );
      final List menu = response.data['menu'];
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
      return MenuItemModel.fromJson(response.data['data']);
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
      return MenuItemModel.fromJson(response.data['data']);
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

lib/services/order_service.dart:
  REPLACE: all Firestore order streams
  WITH: HTTP + polling for real-time

  class OrderService {
    final Dio _dio = apiClient.client;

    Future<OrderModel> createOrder({
      required String restaurantId,
      required String town,
      required List<Map<String, dynamic>> items,
      required double totalAmount,
      required String paymentMethod,
      required String landmark,
    }) async {
      final response = await _dio.post(
        ApiConstants.orders,
        data: {
          'restaurantId': restaurantId,
          'town': town,
          'items': items,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'landmark': landmark,
        },
      );
      return OrderModel.fromJson(response.data);
    }

    // REPLACES: Firestore stream
    // Callers should use Timer.periodic(5s) to poll
    Future<OrderModel?> getOrder(String orderId) async {
      final response = await _dio.get(
        '${ApiConstants.orders}/$orderId',
      );
      return OrderModel.fromJson(response.data['data']);
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
      final List orders = response.data['data'] ?? [];
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
      final List orders = response.data['data'] ?? [];
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
      return OrderModel.fromJson(response.data['data']);
    }

    Future<OrderModel> acceptOrder(
      String orderId,
      String agentId,
    ) async {
      final response = await _dio.put(
        '${ApiConstants.orders}/$orderId/agent',
        data: {'agentId': agentId, 'status': 'delivering'},
      );
      return OrderModel.fromJson(response.data['data']);
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

lib/services/agent_service.dart:
  REPLACE: Firestore agent KYC operations

  class AgentService {
    final Dio _dio = apiClient.client;

    Future<Map<String, dynamic>> submitKyc(
      Map<String, dynamic> kycData
    ) async {
      final response = await _dio.post(
        ApiConstants.agentKyc,
        data: kycData,
      );
      return response.data;
    }

    // REPLACES: Firestore KYC status stream
    // Poll every 30s from KYC pending screen
    Future<String> getKycStatus(String agentId) async {
      final response = await _dio.get(
        '${ApiConstants.agentKycStatus}/$agentId/kyc-status',
      );
      return response.data['status'];
    }

    Future<void> toggleOnlineStatus(
      String agentId,
      bool isOnline, {
      double? latitude,
      double? longitude,
    }) async {
      await _dio.put(
        '${ApiConstants.agentKycStatus}/$agentId/online-status',
        data: {
          'isOnline': isOnline,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
    }

    Future<Map<String, dynamic>> getEarnings(
      String agentId, {
      String period = 'today',
    }) async {
      final response = await _dio.get(
        '${ApiConstants.agentKycStatus}/$agentId/earnings',
        queryParameters: {'period': period},
      );
      return response.data;
    }

    Future<List<Map<String, dynamic>>> getPendingAgents() async {
      final response = await _dio.get(
        '${ApiConstants.adminAgents}/pending',
      );
      final List list = response.data['agents'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }

    Future<void> approveAgent(String agentId) async {
      await _dio.put(
        '${ApiConstants.adminAgents}/$agentId/approve',
      );
    }

    Future<void> rejectAgent(
      String agentId,
      String reason,
    ) async {
      await _dio.put(
        '${ApiConstants.adminAgents}/$agentId/reject',
        data: {'rejectionReason': reason},
      );
    }
  }

lib/services/upload_service.dart:
  REPLACE: Firebase Storage upload
  WITH: Multipart upload to backend

  class UploadService {
    final Dio _dio = apiClient.client;

    // REPLACES: FirebaseStorage.instance.ref().putData()
    Future<String> uploadImage(
      Uint8List imageBytes,
      String fileName, {
      String type = 'restaurant',
    }) async {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
        'type': type,
      });

      final response = await _dio.post(
        ApiConstants.upload,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.data['fullUrl'] ?? '';
    }
  }

════════════════════════════════════════════════════════
SECTION 6 — SCREEN UPDATES (MINIMUM CHANGES)
════════════════════════════════════════════════════════

Rule: Change ONLY the data source. Never change UI widgets,
layout, colors, or navigation structure.

── screens/onboarding/splash_screen.dart ──────────────
REMOVE:
  FirebaseAuth.instance.currentUser check

REPLACE WITH:
  final isLoggedIn = await AuthService().isLoggedIn();
  if (!isLoggedIn) {
    navigate to LoginScreen
    return;
  }
  final userJson = await TokenStorage.getUser();
  final user = UserModel.fromJson(jsonDecode(userJson!));
  // Route by role — keep existing routing logic
  switch (user.role) {
    case 'customer': navigate to CustomerMain; break;
    case 'restaurant': navigate to RestaurantPartnerPage; break;
    case 'agent': navigate to AgentMain; break;
    case 'admin': navigate to AdminPanel; break;
  }

── screens/onboarding/login_screen.dart ───────────────
REMOVE:
  FirebaseAuth phone verification
  FirebaseAuth credential sign-in
  verificationId handling
  PhoneAuthProvider usage

REPLACE send OTP button handler:
  try {
    await AuthService().verifyPhone(phoneController.text);
    setState(() => showOtpField = true);
    // existing UI for OTP field shows automatically
  } on OtpCooldownException catch (e) {
    showSnackBar(e.message);  // "Wait Xs before resending"
  } on NetworkException catch (e) {
    showSnackBar(e.message);
  }

REPLACE verify OTP button handler:
  try {
    final user = await AuthService().signInWithOtp(
      phone: phoneController.text,
      otp: otpController.text,
      role: selectedRole,  // "customer"|"restaurant"|"agent"
      name: nameController.text,
      town: selectedTown,
    );
    // existing role-based navigation — keep exactly as-is
    navigateByRole(user.role);
  } on InvalidOtpException catch (e) {
    showSnackBar(e.message); // "X attempts left"
  } on ApiException catch (e) {
    showSnackBar(e.message);
  }

REMOVE: resend OTP Firebase call
REPLACE:
  Same as send OTP above — call AuthService().verifyPhone()

── screens/customer/customer_home.dart ────────────────
REMOVE:
  DatabaseService.getRestaurantsByTown() Firestore stream
  StreamBuilder wrapper

REPLACE WITH:
  // In initState:
  _loadRestaurants();
  // Start polling every 30s
  _timer = Timer.periodic(
    const Duration(seconds: 30), (_) => _loadRestaurants());

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    try {
      final restaurants = await RestaurantService()
        .getRestaurantsByTown(userTown);
      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // In dispose:
  _timer?.cancel();

  // KEEP: existing StreamBuilder → replace with ListView.builder
  // using _restaurants list. Widget tree stays identical.

── screens/customer/cart_screen.dart ──────────────────
REMOVE:
  DatabaseService.createOrder() Firestore call

REPLACE place order button:
  try {
    setState(() => _isPlacingOrder = true);
    final order = await OrderService().createOrder(
      restaurantId: widget.restaurantId,
      town: userProvider.town,
      items: cartItems.map((item) => {
        'itemId': item.itemId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'totalPrice': item.price * item.quantity,
      }).toList(),
      totalAmount: _cartTotal + 20 + 8, // + delivery + tax
      paymentMethod: selectedPayment == 'upi' ? 'upi' : 'cash',
      landmark: landmarkController.text,
    );
    // Navigate to order tracking — keep existing navigation
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OrderTracking(orderId: order.id),
    ));
  } catch (e) {
    showSnackBar('Failed to place order: $e');
  } finally {
    setState(() => _isPlacingOrder = false);
  }

── screens/customer/order_tracking.dart ───────────────
REMOVE:
  DatabaseService.getOrder() Firestore stream
  StreamBuilder wrapper

REPLACE WITH polling:
  // Pass orderId to this screen
  // In initState: start polling
  _loadOrder();
  _timer = Timer.periodic(
    const Duration(seconds: 5), (_) => _loadOrder());

  Future<void> _loadOrder() async {
    final order = await OrderService().getOrder(widget.orderId);
    if (order != null) {
      setState(() => _order = order);
      // Map order.status to timeline step
      _updateTimeline(order.status);
      // If delivered: cancel timer
      if (order.status == 'delivered') _timer?.cancel();
    }
  }

  // Status to step index mapping:
  int _statusToStep(String status) {
    switch (status) {
      case 'received': return 0;
      case 'preparing': return 1;
      case 'pickup_ready': return 1;
      case 'delivering': return 2;
      case 'delivered': return 3;
      default: return 0;
    }
  }

  // Keep: existing timeline widget — only update step index

── screens/restaurant/restaurant_partner_page.dart ─────
REMOVE:
  DatabaseService.registerRestaurant() Firestore call
  Firebase Storage image upload

REPLACE submit button:
  // Step 3: upload image if selected
  String imageUrl = '';
  if (_imageBytes != null) {
    imageUrl = await UploadService().uploadImage(
      _imageBytes!, _imageName, type: 'restaurant');
  }

  // Step 4: submit
  await RestaurantService().registerRestaurant({
    'shopName': shopNameController.text,
    'ownerName': ownerNameController.text,
    'phone': phoneController.text,
    'email': emailController.text,
    'town': selectedTown,
    'address': addressController.text,
    'cuisineType': selectedCuisine,
    'fssaiNumber': fssaiController.text,
    'status': 'pending',
    'restaurantImageUrl': imageUrl,
  });
  // Keep existing navigation to RestaurantWaitingScreen

── screens/restaurant/restaurant_waiting_screen.dart ───
REMOVE:
  Firestore stream listening for status change

REPLACE WITH polling:
  _timer = Timer.periodic(
    const Duration(seconds: 10),
    (_) async {
      final restaurant = await RestaurantService()
        .getRestaurantById(restaurantId);
      if (restaurant?.status == 'active') {
        _timer?.cancel();
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => RestaurantMain()));
      }
    }
  );

── screens/restaurant/restaurant_dashboard.dart ─────────
REMOVE:
  Firestore stream for orders and restaurant status

REPLACE WITH polling:
  _loadDashboard();
  _timer = Timer.periodic(
    const Duration(seconds: 10), (_) => _loadDashboard());

  Future<void> _loadDashboard() async {
    final orders = await OrderService()
      .getOrdersForRestaurant(restaurantId);
    final restaurant = await RestaurantService()
      .getRestaurantById(restaurantId);
    setState(() {
      _orders = orders;
      _restaurant = restaurant;
    });
  }

  // Toggle online:
  await RestaurantService()
    .toggleOnlineStatus(restaurantId, newValue);

── screens/restaurant/menu_management.dart ─────────────
REMOVE:
  Firestore stream for menu
  Firebase Storage image upload for menu items

REPLACE:
  // Load menu:
  final menu = await MenuService()
    .getMenuForRestaurant(restaurantId);
  setState(() => _menuItems = menu);

  // Add item:
  await MenuService().addMenuItem(restaurantId, {
    'name': nameController.text,
    'description': descController.text,
    'price': double.parse(priceController.text),
    'category': selectedCategory,
    'available': _isAvailable,
    'imageUrl': imageUrl,
    'isSpecial': false,
    'preparationTime': 15,
    'isVeg': _isVeg,
  });

  // Update item:
  await MenuService().updateMenuItem(
    restaurantId, item.id, {'available': false});

  // Delete item:
  await MenuService().deleteMenuItem(restaurantId, item.id);

── screens/agent/delivery_dashboard_page.dart ───────────
REMOVE:
  Firestore KYC status stream

REPLACE:
  // Check KYC status on load:
  final status = await AgentService()
    .getKycStatus(currentUser.uid);
  // Map to KYCStatus enum — keep existing enum and routing

  // Toggle online with location:
  final pos = await Geolocator.getCurrentPosition();
  await AgentService().toggleOnlineStatus(
    agentId, true,
    latitude: pos.latitude,
    longitude: pos.longitude,
  );

── screens/agent/available_orders.dart ─────────────────
REMOVE:
  Firestore stream for available orders

REPLACE WITH polling:
  _loadOrders();
  _timer = Timer.periodic(
    const Duration(seconds: 10), (_) => _loadOrders());

  Future<void> _loadOrders() async {
    final orders = await OrderService()
      .getAvailableOrders(userTown);
    setState(() => _orders = orders);
  }

  // Accept order:
  await OrderService().acceptOrder(order.id, currentUser.uid);

── screens/agent/active_delivery.dart ──────────────────
REMOVE:
  Firestore OTP verification

REPLACE complete delivery:
  final result = await OrderService().completeDelivery(
    orderId: order.id,
    deliveredOtp: otpController.text,
    agentId: currentUser.uid,
  );
  // Show: "Delivery completed! ₹${result['earnedAmount']} credited."
  // Keep existing success UI

── screens/agent/earnings_screen.dart ──────────────────
REMOVE:
  Firestore earnings data

REPLACE:
  final data = await AgentService()
    .getEarnings(currentUser.uid, period: 'today');
  setState(() {
    _todayEarnings = data['today']['totalEarnings'];
    _deliveries = data['today']['deliveries'];
    _weekly = data['weekly'];
  });
  // Keep existing bar chart widget — just feed new data

── screens/agent/delivery_kyc_page.dart ────────────────
REMOVE:
  Firestore KYC submission
  Firebase Storage image uploads

REPLACE:
  // Upload each photo:
  final aadhaarUrl = await UploadService().uploadImage(
    _aadhaarBytes!, 'aadhaar.jpg', type: 'kyc');

  // Submit all steps:
  await AgentService().submitKyc({
    'agentId': currentUser.uid,
    'step1': {
      'fullName': fullNameController.text,
      'dob': dobController.text,
      'gender': selectedGender,
      'address': addressController.text,
    },
    'step2': {
      'aadhaarNumber': aadhaarController.text,
      'aadhaarPhotoUrl': aadhaarUrl,
      'panNumber': panController.text,
    },
    'step3': {
      'vehicleType': selectedVehicle,
      'registrationNumber': regController.text,
      'insurancePhotoUrl': insuranceUrl,
      'rcPhotoUrl': rcUrl,
    },
    'step4': {
      'accountHolderName': holderController.text,
      'accountNumber': accountController.text,
      'ifscCode': ifscController.text,
      'bankName': bankController.text,
    },
    'status': 'pending',
  });
  // Navigate to KYCPendingPage — keep existing

── screens/agent/kyc_pending_page.dart ─────────────────
REMOVE:
  Firestore KYC status stream

REPLACE WITH polling:
  _timer = Timer.periodic(
    const Duration(seconds: 15),
    (_) async {
      final status = await AgentService()
        .getKycStatus(currentUser.uid);
      if (status == 'approved') {
        _timer?.cancel();
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => AgentMain()));
      }
      if (status == 'rejected') {
        _timer?.cancel();
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => KYCRejectedPage()));
      }
    }
  );

── screens/admin/admin_panel.dart ──────────────────────
REMOVE:
  Firestore streams for pending restaurants and agents

REPLACE:
  // Restaurants tab:
  final restaurants = await RestaurantService()
    .getPendingRestaurants();

  // Approve:
  await RestaurantService()
    .updateRestaurantStatus(restaurant.id, 'active');

  // Reject:
  await RestaurantService().updateRestaurantStatus(
    restaurant.id, 'rejected',
    rejectionReason: reasonController.text);

  // Agents tab:
  final agents = await AgentService().getPendingAgents();

  // Approve agent:
  await AgentService().approveAgent(agent['agentId']);

  // Reject agent:
  await AgentService().rejectAgent(
    agent['agentId'], reasonController.text);

════════════════════════════════════════════════════════
SECTION 7 — PROVIDER UPDATES
════════════════════════════════════════════════════════

lib/providers/auth_provider.dart:
  REMOVE: FirebaseAuth listener (onAuthStateChanged)
  REPLACE:
    On app start: check TokenStorage.hasToken()
    Load user from TokenStorage.getUser()
    Update UserProvider with loaded user

  class AuthProvider extends ChangeNotifier {
    UserModel? _user;
    bool _isLoading = true;

    Future<void> initialize() async {
      final hasToken = await TokenStorage.hasToken();
      if (hasToken) {
        final userJson = await TokenStorage.getUser();
        if (userJson != null) {
          _user = UserModel.fromJson(jsonDecode(userJson));
        }
      }
      _isLoading = false;
      notifyListeners();
    }

    Future<void> logout() async {
      await AuthService().signOut();
      _user = null;
      notifyListeners();
    }
  }

════════════════════════════════════════════════════════
SECTION 8 — CONFIGURATION
════════════════════════════════════════════════════════

IP Address setup (CRITICAL for mobile):
  1. Run: ipconfig (Windows) or ifconfig (Mac/Linux)
  2. Find IPv4 address (e.g., 192.168.1.105)
  3. Update in lib/core/api_constants.dart:
     static const String baseIP = '192.168.1.105';
  4. Ensure phone and laptop are on same WiFi network
  5. Ensure backend is running on: uvicorn app.main:app
     --host 0.0.0.0 --port 8000
     (NOT --host 127.0.0.1 — that blocks mobile)

CORS on backend (already set but verify):
  In app/main.py CORSMiddleware:
  allow_origins=["*"]  ← needed for Flutter mobile

════════════════════════════════════════════════════════
SECTION 9 — TESTING CHECKLIST
════════════════════════════════════════════════════════

For each screen, test:
  [ ] Login flow (send OTP → verify → route by role)
  [ ] Customer: browse restaurants → view menu → add cart → order
  [ ] Restaurant: register → wait → dashboard → toggle open
  [ ] Restaurant: add menu item → update availability
  [ ] Restaurant: receive order → accept → mark ready
  [ ] Agent: submit KYC → pending → approved (via admin)
  [ ] Agent: go online → see available orders → accept → deliver
  [ ] Agent: earnings tab shows real data
  [ ] Admin: approve restaurant → appears to customers
  [ ] Admin: approve agent KYC → agent can work

════════════════════════════════════════════════════════
SECTION 10 — WHAT MUST NOT CHANGE
════════════════════════════════════════════════════════
  ✗ No widget tree changes
  ✗ No color changes
  ✗ No font changes
  ✗ No navigation structure changes
  ✗ No screen layout changes
  ✗ No animation changes
  ✗ No state management architecture changes
  ✗ No folder restructuring beyond adding new files