// No Firebase/Firestore imports — all models now parsed from JSON backend responses.

// ─────────────────────────────────────────────────────────────────────────────
// UserModel
// ─────────────────────────────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String role; // 'customer', 'restaurant', 'agent', 'admin'
  final String town;
  final String status; // 'active', 'pending', 'rejected'
  final String? kycStatus; // for agents
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

  /// Legacy constructor — kept for backward compatibility with existing screens.
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      town: data['town'] ?? '',
      status: data['status'] ?? 'active',
      kycStatus: data['kycStatus'],
      restaurantStatus: data['restaurantStatus'],
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  /// Parses backend JSON response (from /auth/verify-otp and /users).
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

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'town': town,
      'status': status,
      'kycStatus': kycStatus,
      'restaurantStatus': restaurantStatus,
    };
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'role': role,
        'town': town,
        'status': status,
        'kycStatus': kycStatus,
        'restaurantStatus': restaurantStatus,
      };
}

class AddressModel {
  final String id;
  final String label;
  final String fullAddress;
  final String landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String flatNumber;
  final String contactName;
  final String contactPhone;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.flatNumber = '',
    this.contactName = '',
    this.contactPhone = '',
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return AddressModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'OTHER',
      fullAddress: json['full_address']?.toString() ??
          json['fullAddress']?.toString() ??
          '',
      landmark: json['landmark']?.toString() ?? '',
      latitude: asDouble(json['latitude'] ?? json['lat']),
      longitude: asDouble(json['longitude'] ?? json['lng']),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      flatNumber: json['flat_number']?.toString() ??
          json['flatNumber']?.toString() ??
          '',
      contactName: json['contact_name']?.toString() ??
          json['contactName']?.toString() ??
          '',
      contactPhone: json['contact_phone']?.toString() ??
          json['contactPhone']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'full_address': fullAddress,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
        'flat_number': flatNumber,
        'contact_name': contactName,
        'contact_phone': contactPhone,
      };
}

class CartRestaurantModel {
  final String id;
  final String name;
  final bool isOpen;
  final double deliveryFee;

  const CartRestaurantModel({
    required this.id,
    required this.name,
    this.isOpen = true,
    this.deliveryFee = 0,
  });

  factory CartRestaurantModel.fromJson(Map<String, dynamic> json) {
    return CartRestaurantModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isOpen: json['is_open'] == true || json['isOpen'] == true,
      deliveryFee: (json['delivery_fee'] ?? json['deliveryFee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_open': isOpen,
        'delivery_fee': deliveryFee,
      };
}

class CartItemModel {
  final String menuItemId;
  final String name;
  final int quantity;
  final double price;
  final double? discountedPrice;
  final double effectivePrice;
  final double itemTotal;

  const CartItemModel({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.discountedPrice,
    required this.effectivePrice,
    required this.itemTotal,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final effective = (json['effective_price'] ?? json['effectivePrice'] ?? json['price'] ?? 0).toDouble();
    final quantity = (json['quantity'] ?? 0) as int;
    return CartItemModel(
      menuItemId: json['menu_item_id']?.toString() ??
          json['menuItemId']?.toString() ??
          json['itemId']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      quantity: quantity,
      price: (json['price'] ?? effective).toDouble(),
      discountedPrice: json['discounted_price'] == null
          ? null
          : (json['discounted_price'] as num).toDouble(),
      effectivePrice: effective,
      itemTotal: (json['item_total'] ?? json['itemTotal'] ?? effective * quantity).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'menu_item_id': menuItemId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'discounted_price': discountedPrice,
        'effective_price': effectivePrice,
        'item_total': itemTotal,
      };
}

class CartState {
  final CartRestaurantModel? restaurant;
  final List<CartItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double grandTotal;
  final int itemCount;

  const CartState({
    this.restaurant,
    this.items = const [],
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.grandTotal = 0,
    this.itemCount = 0,
  });

  bool get hasItems => itemCount > 0;

  static const empty = CartState();

  factory CartState.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
    final restaurantJson = data['restaurant'];
    return CartState(
      restaurant: restaurantJson is Map
          ? CartRestaurantModel.fromJson(Map<String, dynamic>.from(restaurantJson))
          : null,
      items: ((data['items'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      subtotal: (data['cart_subtotal'] ?? data['subtotal'] ?? data['items_total'] ?? 0).toDouble(),
      deliveryFee: (data['delivery_fee'] ?? 0).toDouble(),
      grandTotal: (data['grand_total'] ?? 0).toDouble(),
      itemCount: (data['item_count'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'restaurant': restaurant?.toJson(),
        'items': items.map((item) => item.toJson()).toList(),
        'cart_subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'grand_total': grandTotal,
        'item_count': itemCount,
      };
}

class CartValidationResult {
  final bool isValid;
  final List<String> invalidItems;
  final bool restaurantIsOpen;

  const CartValidationResult({
    required this.isValid,
    required this.invalidItems,
    required this.restaurantIsOpen,
  });

  factory CartValidationResult.fromJson(Map<String, dynamic> json) {
    return CartValidationResult(
      isValid: json['is_valid'] == true || json['isValid'] == true,
      invalidItems: ((json['invalid_items'] ?? json['invalidItems']) as List? ?? [])
          .map((item) {
            if (item is Map) return item['name']?.toString() ?? item.toString();
            return item.toString();
          })
          .toList(),
      restaurantIsOpen: json['restaurant_is_open'] != false &&
          json['restaurantIsOpen'] != false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RestaurantModel
// ─────────────────────────────────────────────────────────────────────────────
class RestaurantModel {
  final String id;
  final String shopName;
  final String ownerName;
  final String phone;
  final String email;
  final String town;
  final String address;
  final String cuisineType;
  final String upiId;
  final String fssaiNumber;
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

  RestaurantModel({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.town,
    required this.address,
    required this.cuisineType,
    this.upiId = '',
    required this.fssaiNumber,
    required this.status,
    this.fssaiPhotoUrl = '',
    this.kitchenPhotoUrl = '',
    this.signboardPhotoUrl = '',
    this.restaurantImageUrl = '',
    this.isOpen = false,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.deliveryFee = 0.0,
    this.minOrderAmount = 0.0,
    this.avgDeliveryTime = 30,
  });

  /// Legacy constructor — kept for backward compatibility.
  factory RestaurantModel.fromMap(Map<String, dynamic> data, String id) {
    return RestaurantModel(
      id: id,
      shopName: data['shopName'] ?? '',
      ownerName: data['ownerName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      town: data['town'] ?? '',
      address: data['address'] ?? '',
      cuisineType: data['cuisineType'] ?? '',
      upiId: data['upiId'] ?? '',
      fssaiNumber: data['fssaiNumber'] ?? '',
      status: data['status'] ?? 'pending',
      fssaiPhotoUrl: data['fssaiPhotoUrl'] ?? '',
      kitchenPhotoUrl: data['kitchenPhotoUrl'] ?? '',
      signboardPhotoUrl: data['signboardPhotoUrl'] ?? '',
      restaurantImageUrl: data['restaurantImageUrl'] ?? '',
      isOpen: data['isOpen'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
      minOrderAmount: (data['minOrderAmount'] ?? 0.0).toDouble(),
      avgDeliveryTime: data['avgDeliveryTime'] ?? 30,
    );
  }

  /// Parses backend JSON response (from /restaurants and /restaurants/:id).
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
      upiId: json['upiId'] ?? '',
      fssaiNumber: json['fssaiNumber'] ?? '',
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

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'town': town,
      'address': address,
      'cuisineType': cuisineType,
      'upiId': upiId,
      'fssaiNumber': fssaiNumber,
      'status': status,
      'fssaiPhotoUrl': fssaiPhotoUrl,
      'kitchenPhotoUrl': kitchenPhotoUrl,
      'signboardPhotoUrl': signboardPhotoUrl,
      'restaurantImageUrl': restaurantImageUrl,
      'isOpen': isOpen,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OrderItemModel
// ─────────────────────────────────────────────────────────────────────────────
class OrderItemModel {
  final String itemId;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;

  OrderItemModel({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final price = _asDouble(json['price']);
    final quantity = _asInt(json['quantity']);
    return OrderItemModel(
      itemId: (json['itemId'] ?? json['menu_item_id'] ?? json['menuItemId'])
              ?.toString() ??
          '',
      name: json['name'] ?? '',
      quantity: quantity,
      price: price,
      totalPrice:
          _asDouble(json['totalPrice'] ?? json['item_total'] ?? price * quantity),
    );
  }

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'totalPrice': totalPrice,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// OrderModel
// ─────────────────────────────────────────────────────────────────────────────
class OrderModel {
  final String id;
  final String customerId;
  final String restaurantId;
  final String? agentId;
  final String town;
  final List<Map<String, dynamic>> items; // kept for backward compat
  final List<OrderItemModel> orderItems; // new typed list
  final double totalAmount;
  final String paymentMethod;
  final String landmark;
  final String status; // 'received','preparing','pickup_ready','delivering','delivered'
  final String? pickupCode;
  final String? deliveryOtp;
  final double? restaurantLatitude;
  final double? restaurantLongitude;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final String restaurantName;
  final String restaurantAddress;
  final String partnerName;
  final String partnerPhone;
  final String partnerVehicleNumber;
  final double partnerRating;
  final double itemsTotal;
  final double deliveryFee;
  final double totalPaid;
  final int estimatedMinutes;
  final Map<String, dynamic> raw;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    this.agentId,
    required this.town,
    required this.items,
    List<OrderItemModel>? orderItems,
    required this.totalAmount,
    required this.paymentMethod,
    required this.landmark,
    required this.status,
    this.pickupCode,
    this.deliveryOtp,
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.customerLatitude,
    this.customerLongitude,
    this.partnerLatitude,
    this.partnerLongitude,
    this.restaurantName = '',
    this.restaurantAddress = '',
    this.partnerName = '',
    this.partnerPhone = '',
    this.partnerVehicleNumber = '',
    this.partnerRating = 0,
    this.itemsTotal = 0,
    this.deliveryFee = 0,
    this.totalPaid = 0,
    this.estimatedMinutes = 0,
    this.raw = const {},
    required this.createdAt,
    this.updatedAt,
  }) : orderItems = orderItems ?? [];

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double _asDoubleValue(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _asIntValue(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().toUpperCase();
    switch (status) {
      case 'PLACED':
      case 'RECEIVED':
        return 'received';
      case 'CONFIRMED':
        return 'confirmed';
      case 'PREPARING':
        return 'preparing';
      case 'READY':
      case 'READY_FOR_PICKUP':
      case 'PICKUP_READY':
        return 'pickup_ready';
      case 'OUT_FOR_DELIVERY':
      case 'DELIVERING':
      case 'PICKED_UP':
        return 'delivering';
      case 'DELIVERED':
        return 'delivered';
      case 'CANCELLED':
      case 'CANCELED':
        return 'cancelled';
      default:
        return value?.toString() ?? 'received';
    }
  }

  static Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// Legacy constructor — kept for backward compatibility with existing screens.
  factory OrderModel.fromMap(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      customerId: data['customerId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      agentId: data['agentId'],
      town: data['town'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'COD',
      landmark: data['landmark'] ?? '',
      status: data['status'] ?? 'received',
      pickupCode: data['pickupCode']?.toString(),
      deliveryOtp: data['deliveryOtp']?.toString(),
      restaurantLatitude: _asNullableDouble(data['restaurantLatitude']),
      restaurantLongitude: _asNullableDouble(data['restaurantLongitude']),
      customerLatitude: _asNullableDouble(data['customerLatitude']),
      customerLongitude: _asNullableDouble(data['customerLongitude']),
      partnerLatitude: _asNullableDouble(data['partnerLatitude']),
      partnerLongitude: _asNullableDouble(data['partnerLongitude']),
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Parses backend JSON response (from /orders and /orders/:id).
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
    final rawItems =
        (data['orderItems'] ?? data['items'] ?? data['order_items']) as List? ??
            [];
    final typedItems = rawItems
        .whereType<Map>()
        .map((i) => OrderItemModel.fromJson(Map<String, dynamic>.from(i)))
        .toList();
    final restaurant = _mapFrom(data['restaurant']);
    final partner = _mapFrom(data['partner'] ?? data['delivery_partner']);
    final address = _mapFrom(data['delivery_address'] ?? data['delivery_address_snapshot']);
    final location = _mapFrom(data['partner_location'] ?? data['location']);
    final totals = _mapFrom(data['payment_summary'] ?? data['summary']);
    return OrderModel(
      id: (data['id'] ?? data['order_id'])?.toString() ?? '',
      customerId: (data['customerId'] ?? data['customer_id'] ?? data['user_id'])?.toString() ?? '',
      restaurantId: (data['restaurantId'] ?? data['restaurant_id'])?.toString() ?? '',
      agentId: (data['agentId'] ?? data['agent_id'] ?? data['partner_id'])?.toString(),
      town: (data['town'] ?? data['city'] ?? '')?.toString() ?? '',
      items: rawItems
          .whereType<Map>()
          .map((i) => Map<String, dynamic>.from(i))
          .toList(),
      orderItems: typedItems,
      totalAmount: _asDoubleValue(data['totalAmount'] ?? data['total_amount']),
      paymentMethod: (data['paymentMethod'] ?? data['payment_method'] ?? 'cash').toString(),
      landmark: (data['landmark'] ?? address['landmark'] ?? address['full_address'] ?? '')?.toString() ?? '',
      status: _normalizeStatus(data['status']),
      pickupCode: (data['pickupCode'] ?? data['pickup_code'] ?? data['pickupOtp'] ?? data['pickup_otp'])?.toString(),
      deliveryOtp: (data['deliveryOtp'] ?? data['delivery_otp'] ?? data['otp'])?.toString(),
      restaurantLatitude: _asNullableDouble(data['restaurantLatitude'] ?? data['restaurant_latitude'] ?? restaurant['latitude']),
      restaurantLongitude: _asNullableDouble(data['restaurantLongitude'] ?? data['restaurant_longitude'] ?? restaurant['longitude']),
      customerLatitude: _asNullableDouble(data['customerLatitude'] ?? data['customer_latitude'] ?? address['latitude']),
      customerLongitude: _asNullableDouble(data['customerLongitude'] ?? data['customer_longitude'] ?? address['longitude']),
      partnerLatitude: _asNullableDouble(data['partnerLatitude'] ?? data['partner_latitude'] ?? location['latitude']),
      partnerLongitude: _asNullableDouble(data['partnerLongitude'] ?? data['partner_longitude'] ?? location['longitude']),
      restaurantName: (data['restaurantName'] ?? data['restaurant_name'] ?? restaurant['name'] ?? restaurant['shopName'] ?? '').toString(),
      restaurantAddress: (data['restaurantAddress'] ?? data['restaurant_address'] ?? restaurant['full_address'] ?? restaurant['address'] ?? '').toString(),
      partnerName: (data['partnerName'] ?? data['partner_name'] ?? partner['name'] ?? '').toString(),
      partnerPhone: (data['partnerPhone'] ?? data['partner_phone'] ?? partner['phone'] ?? '').toString(),
      partnerVehicleNumber: (data['partnerVehicleNumber'] ?? data['vehicle_number'] ?? partner['vehicle_number'] ?? '').toString(),
      partnerRating: _asDoubleValue(data['partnerRating'] ?? data['partner_rating'] ?? partner['rating']),
      itemsTotal: _asDoubleValue(data['itemsTotal'] ?? data['items_total'] ?? totals['items_total']),
      deliveryFee: _asDoubleValue(data['deliveryFee'] ?? data['delivery_fee'] ?? totals['delivery_fee']),
      totalPaid: _asDoubleValue(data['totalPaid'] ?? data['total_paid'] ?? data['totalAmount'] ?? data['total_amount']),
      estimatedMinutes: _asIntValue(data['estimatedMinutes'] ?? data['estimated_minutes'] ?? data['preparation_time']),
      raw: data,
      createdAt: DateTime.tryParse(
              (data['createdAt'] ?? data['created_at'])?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: (data['updatedAt'] ?? data['updated_at']) != null
          ? DateTime.tryParse((data['updatedAt'] ?? data['updated_at']).toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'restaurantId': restaurantId,
      'agentId': agentId,
      'town': town,
      'items': items,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'landmark': landmark,
      'status': status,
      'pickupCode': pickupCode,
      'deliveryOtp': deliveryOtp,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MenuItemModel
// ─────────────────────────────────────────────────────────────────────────────
class MenuItemModel {
  final String id;
  final String restaurantId;
  final String category;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isVeg;
  final bool isAvailable; // legacy field name kept
  final bool available;   // backend field name (mapped from isAvailable)
  final bool isSpecial;
  final int preparationTime;

  MenuItemModel({
    required this.id,
    this.restaurantId = '',
    required this.category,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl = '',
    required this.isVeg,
    bool? isAvailable,
    bool? available,
    this.isSpecial = false,
    this.preparationTime = 15,
  })  : isAvailable = isAvailable ?? available ?? true,
        available = available ?? isAvailable ?? true;

  /// Legacy constructor — kept for backward compatibility.
  factory MenuItemModel.fromMap(Map<String, dynamic> data, String id) {
    return MenuItemModel(
      id: id,
      category: data['category'] ?? 'Other',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      isVeg: data['isVeg'] ?? true,
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  /// Parses backend JSON response (from /restaurants/:id/menu).
  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    final avail = json['available'] ?? json['isAvailable'] ?? true;
    return MenuItemModel(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      category: json['category'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      isVeg: json['isVeg'] ?? true,
      isAvailable: avail,
      available: avail,
      isSpecial: json['isSpecial'] ?? false,
      preparationTime: json['preparationTime'] ?? 15,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
      'isAvailable': isAvailable,
    };
  }
}
