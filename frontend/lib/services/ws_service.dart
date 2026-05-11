import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_constants.dart';
import '../core/token_storage.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class WsService with WidgetsBindingObserver {
  WsService._();
  static final WsService instance = WsService._();

  final _customerOrderController = StreamController<OrderModel>.broadcast();
  final _restaurantOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _partnerAssignmentController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<OrderModel> get customerOrderStream => _customerOrderController.stream;
  Stream<Map<String, dynamic>> get restaurantOrderStream => _restaurantOrderController.stream;
  Stream<Map<String, dynamic>> get partnerAssignmentStream => _partnerAssignmentController.stream;

  WebSocketChannel? _customerChannel;
  WebSocketChannel? _restaurantChannel;
  WebSocketChannel? _partnerChannel;
  WebSocketChannel? _locationChannel;

  StreamSubscription? _customerSub;
  StreamSubscription? _restaurantSub;
  StreamSubscription? _partnerSub;
  StreamSubscription<Position>? _positionSub;

  Timer? _customerReconnect;
  Timer? _restaurantReconnect;
  Timer? _partnerReconnect;
  Timer? _locationReconnect;
  Timer? _pingTimer;

  String? _customerOrderId;
  bool _restaurantWanted = false;
  bool _partnerWanted = false;
  bool _locationWanted = false;

  bool _permanentlyStopped = false;

  Future<void> connectCustomerOrder(String orderId) async {
    if (!await _hasRole({'customer', 'CUSTOMER'})) {
      disconnectCustomerOrder();
      return;
    }
    _customerOrderId = orderId;
    await _connectCustomer();
    _ensureLifecycle();
  }

  Future<void> connectRestaurantOrders() async {
    if (!await _hasRole({'restaurant', 'RESTAURANT_PARTNER'})) {
      disconnectRestaurantOrders();
      return;
    }
    disconnectPartnerOrders();
    disconnectCustomerOrder();
    _restaurantWanted = true;
    await _connectRestaurant();
    _ensureLifecycle();
  }

  Future<void> connectPartnerOrders() async {
    if (!await _hasRole({'agent', 'DELIVERY_PARTNER'})) {
      disconnectPartnerOrders();
      return;
    }
    disconnectRestaurantOrders();
    disconnectCustomerOrder();
    _partnerWanted = true;
    await _connectPartner();
    _ensureLifecycle();
  }

  Future<void> connectPartnerLocation() async {
    if (!await _hasRole({'agent', 'DELIVERY_PARTNER'})) {
      disconnectPartnerLocation();
      return;
    }
    _locationWanted = true;
    await _connectLocation();
    await _startLocationStream();
    _ensureLifecycle();
  }

  void disconnectCustomerOrder() {
    _customerOrderId = null;
    _customerReconnect?.cancel();
    _customerSub?.cancel();
    _customerChannel?.sink.close();
    _customerChannel = null;
  }

  void disconnectRestaurantOrders() {
    _restaurantWanted = false;
    _restaurantReconnect?.cancel();
    _restaurantSub?.cancel();
    _restaurantChannel?.sink.close();
    _restaurantChannel = null;
  }

  void disconnectPartnerOrders() {
    _partnerWanted = false;
    _partnerReconnect?.cancel();
    _partnerSub?.cancel();
    _partnerChannel?.sink.close();
    _partnerChannel = null;
  }

  void disconnectPartnerLocation() {
    _locationWanted = false;
    _locationReconnect?.cancel();
    _positionSub?.cancel();
    _locationChannel?.sink.close();
    _locationChannel = null;
  }

  Future<void> _connectCustomer() async {
    final orderId = _customerOrderId;
    if (orderId == null || orderId.isEmpty) return;
    await _customerSub?.cancel();
    _customerChannel?.sink.close();
    final channel = await _open('${ApiConstants.wsBase}/orders/$orderId');
    _customerChannel = channel;
    _customerSub = channel.stream.listen(
      (message) => _handleCustomerMessage(message),
      onDone: () {
        if (!_shouldReconnect(channel)) return;
        _scheduleCustomerReconnect();
      },
      onError: (_) => _scheduleCustomerReconnect(),
      cancelOnError: true,
    );
  }

  Future<void> _connectRestaurant() async {
    if (!_restaurantWanted) return;
    final role = await TokenStorage.getRole();
    debugPrint('WS: _connectRestaurant called (role=$role)');
    if (role != 'restaurant' && role != 'RESTAURANT_PARTNER') {
      debugPrint('WS skip: wrong role $role for restaurant channel');
      _restaurantWanted = false;
      return;
    }
    await _restaurantSub?.cancel();
    _restaurantChannel?.sink.close();
    final channel = await _open('${ApiConstants.wsBase}/restaurant/orders');
    final openedAt = DateTime.now();
    _restaurantChannel = channel;
    _restaurantSub = channel.stream.listen(
      (message) => _restaurantOrderController.add(_decode(message)),
      onDone: () {
        if (_permanentlyStopped) return;
        if (!_shouldReconnect(channel, openedAt)) return;
        _scheduleRestaurantReconnect();
      },
      onError: (_) {
        if (_permanentlyStopped) return;
        if (!_shouldReconnect(channel, openedAt)) return;
        _scheduleRestaurantReconnect();
      },
      cancelOnError: true,
    );
  }

  Future<void> _connectPartner() async {
    if (!_partnerWanted) return;
    final role = await TokenStorage.getRole();
    debugPrint('WS: _connectPartner called (role=$role)');
    if (role != 'agent' && role != 'DELIVERY_PARTNER') {
      debugPrint('WS skip: wrong role $role for partner channel');
      _partnerWanted = false;
      return;
    }
    await _partnerSub?.cancel();
    _partnerChannel?.sink.close();
    final channel = await _open('${ApiConstants.wsBase}/partner/orders');
    final openedAt = DateTime.now();
    _partnerChannel = channel;
    _partnerSub = channel.stream.listen(
      (message) => _partnerAssignmentController.add(_decode(message)),
      onDone: () {
        if (_permanentlyStopped) return;
        if (!_shouldReconnect(channel, openedAt)) return;
        _schedulePartnerReconnect();
      },
      onError: (_) {
        if (_permanentlyStopped) return;
        if (!_shouldReconnect(channel, openedAt)) return;
        _schedulePartnerReconnect();
      },
      cancelOnError: true,
    );
  }

  Future<void> _connectLocation() async {
    if (!_locationWanted) return;
    _locationChannel?.sink.close();
    _locationChannel = await _open('${ApiConstants.wsBase}/partner/location');
  }

  Future<WebSocketChannel> _open(String base) async {
    var token = await TokenStorage.getToken();
    if (token == null || _isExpired(token)) {
      await _refreshAccessToken();
      token = await TokenStorage.getToken();
    }
    if (token == null || token.isEmpty) {
      throw StateError('No valid access token for WebSocket');
    }
    final uri = Uri.parse(base).replace(queryParameters: {
      'token': token,
    });
    return WebSocketChannel.connect(uri);
  }

  Future<bool> _hasRole(Set<String> roles) async {
    final role = await TokenStorage.getRole();
    return role != null && roles.contains(role);
  }

  /// Returns false for close codes that mean "stop retrying".
  /// [openedAt] is when the channel was created; if it closed in < 2s
  /// with a null code, it was almost certainly a server rejection.
  bool _shouldReconnect(WebSocketChannel channel, [DateTime? openedAt]) {
    final code = channel.closeCode;
    debugPrint('WS close code=$code reason=${channel.closeReason}');
    if (code == 4003) {
      debugPrint('WS 4003 — wrong role, not reconnecting');
      _permanentlyStopped = true;
      return false;
    }
    if (code == 4001) {
      debugPrint('WS 4001 — invalid token, not reconnecting');
      return false;
    }
    if (code == 1000) {
      debugPrint('WS 1000 — clean close, not reconnecting');
      return false;
    }
    // Flutter web: closeCode may be null even for 4003; if connection lived
    // less than 2 seconds it was a server-side rejection → stop retrying.
    if (code == null && openedAt != null) {
      final ms = DateTime.now().difference(openedAt).inMilliseconds;
      if (ms < 2000) {
        debugPrint('WS fast-close ${ms}ms (code=null) — treating as rejection, not reconnecting');
        return false;
      }
    }
    // 1006 (network drop) or genuinely unknown → reconnect
    return true;
  }

  bool _isExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 20)));
    } catch (_) {
      return true;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await TokenStorage.clearAll();
      return null;
    }
    try {
      final response = await Dio(BaseOptions(baseUrl: ApiConstants.apiBase)).post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final access = (data['token'] ?? data['access_token'])?.toString();
      final refresh = (data['refreshToken'] ?? data['refresh_token'])?.toString();
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        return null;
      }
      await TokenStorage.saveToken(access);
      await TokenStorage.saveRefreshToken(refresh);
      return access;
    } catch (_) {
      await TokenStorage.clearAll();
      return null;
    }
  }

  Map<String, dynamic> _decode(dynamic message) {
    if (message is Map<String, dynamic>) return message;
    final decoded = jsonDecode(message.toString());
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  void _handleCustomerMessage(dynamic message) {
    final event = _decode(message);
    final data = event['order'] ?? event['data'] ?? event;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['id'] == null && map['order_id'] == null) return;
      _customerOrderController.add(OrderModel.fromJson(map));
    }
  }

  void _scheduleCustomerReconnect() {
    _customerReconnect?.cancel();
    if (_customerOrderId == null) return;
    _customerReconnect = Timer(const Duration(seconds: 3), _connectCustomer);
  }

  void _scheduleRestaurantReconnect() {
    if (_permanentlyStopped) return;
    _restaurantReconnect?.cancel();
    if (!_restaurantWanted) return;
    _restaurantReconnect = Timer(const Duration(seconds: 3), _connectRestaurant);
  }

  void _schedulePartnerReconnect() {
    if (_permanentlyStopped) return;
    _partnerReconnect?.cancel();
    if (!_partnerWanted) return;
    _partnerReconnect = Timer(const Duration(seconds: 3), _connectPartner);
  }

  void _scheduleLocationReconnect() {
    _locationReconnect?.cancel();
    if (!_locationWanted) return;
    _locationReconnect = Timer(const Duration(seconds: 3), _connectLocation);
  }

  Future<void> _startLocationStream() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      final payload = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_kmph': (position.speed * 3.6).clamp(0, 220),
        'heading_degrees': position.heading.isNaN ? 0 : position.heading.round(),
      };
      try {
        _locationChannel?.sink.add(jsonEncode(payload));
      } catch (_) {
        _scheduleLocationReconnect();
      }
    });
  }

  void _ensureLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    _pingTimer ??= Timer.periodic(const Duration(seconds: 25), (_) => _pingAll());
  }

  void _pingAll() {
    final ping = jsonEncode({'type': 'PING', 'ts': DateTime.now().toIso8601String()});
    for (final channel in [_customerChannel, _restaurantChannel, _partnerChannel, _locationChannel]) {
      try {
        channel?.sink.add(ping);
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pingTimer ??= Timer.periodic(const Duration(seconds: 25), (_) => _pingAll());
    }
    if (state == AppLifecycleState.resumed) {
      if (_customerOrderId != null && _customerChannel == null) _scheduleCustomerReconnect();
      if (_restaurantWanted && _restaurantChannel == null) _scheduleRestaurantReconnect();
      if (_partnerWanted && _partnerChannel == null) _schedulePartnerReconnect();
      if (_locationWanted && _locationChannel == null) _scheduleLocationReconnect();
    }
  }
}
