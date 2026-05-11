import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../services/agent_service.dart';
import '../services/order_service.dart';
import '../services/upload_service.dart';
import '../services/ws_service.dart';
import '../core/token_storage.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum DeliveryStep { goToRestaurant, pickupOrder, navigateToCustomer, delivered }
enum KYCStatus { notSubmitted, pending, approved, rejected }

class EarningsRecord {
  final String day;
  final double amount;
  final int deliveries;
  const EarningsRecord({required this.day, required this.amount, required this.deliveries});
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA (Weekly Earnings)
// ─────────────────────────────────────────────────────────────────────────────
List<EarningsRecord> _emptyWeek() {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days
      .map((day) => EarningsRecord(day: day, amount: 0, deliveries: 0))
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryProvider extends ChangeNotifier {
  // ── User Identity ─────────────────────────────────────
  String _currentAgentId = '';
  String get currentAgentId => _currentAgentId;

  // ── KYC Status ────────────────────────────────────────
  KYCStatus _kycStatus = KYCStatus.notSubmitted;
  KYCStatus get kycStatus => _kycStatus;

  int _currentKycStep = 0;
  int get currentKycStep => _currentKycStep;

  void nextKycStep() {
    if (_currentKycStep < 2) {
      _currentKycStep++;
      notifyListeners();
    }
  }

  void prevKycStep() {
    if (_currentKycStep > 0) {
      _currentKycStep--;
      notifyListeners();
    }
  }

  // ── Per-User Initialization ──────────────────────────
  Future<void> initForUser(String agentId, {String town = ''}) async {
    if (agentId.isEmpty) return;
    final changedUser = _currentAgentId != agentId;
    _currentAgentId = agentId;
    if (town.trim().isNotEmpty) _currentCity = town.trim();

    if (changedUser) {
      _currentKycStep = 0;
      _isOnline = false;
      _availableOrders = [];
      _activeOrder = null;
      _hasActiveOrder = false;
      _todayEarnings = 0;
      _todayDeliveries = 0;
      _weeklyData = _emptyWeek();

      nameController.clear();
      phoneController.clear();
      emailController.clear();
      idNumberController.clear();
      licenseNumberController.clear();
      vehicleNumberController.clear();
      profilePhoto = null;
      aadhaarImage = null;
      licenseImage = null;
    }

    await _loadKYCData();
    notifyListeners();
    
    // Polling for available orders if approved and online
    _startOrdersPolling();
  }

  Timer? _pollingTimer;
  StreamSubscription<Map<String, dynamic>>? _assignmentSub;
  Timer? _surgeTimer;
  Map<String, dynamic>? _activeAssignment;
  Map<String, dynamic>? _latestRequest;
  Map<String, dynamic>? _surgeStatus;
  Map<String, dynamic>? get activeAssignment => _activeAssignment;
  Map<String, dynamic>? get latestRequest => _latestRequest;
  Map<String, dynamic>? get surgeStatus => _surgeStatus;

  void _startOrdersPolling() {
    _pollingTimer?.cancel();
    WsService.instance.connectPartnerOrders();
    _assignmentSub?.cancel();
    _assignmentSub = WsService.instance.partnerAssignmentStream.listen(_handleAssignmentEvent);
    _loadSurgeStatus();
    _surgeTimer?.cancel();
    _surgeTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadSurgeStatus());
  }

  void _handleAssignmentEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? event['event'] ?? '').toString();
    final data = type == 'NEW_ORDER'
        ? event
        : event['assignment'] ?? event['order'] ?? event['data'] ?? event;
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (type == 'NEW_ORDER' || map['order'] is Map) {
      final assignmentMap = map['assignment'] is Map
          ? Map<String, dynamic>.from(map['assignment'] as Map)
          : null;
      final nestedOrder = assignmentMap == null ? null : assignmentMap['order'];
      _latestRequest = assignmentMap ?? map;
      final orderMap = map['order'] is Map
          ? Map<String, dynamic>.from(map['order'] as Map)
          : nestedOrder is Map
              ? Map<String, dynamic>.from(nestedOrder)
              : map;
      final order = OrderModel.fromJson(orderMap);
      _availableOrders.removeWhere((item) => item.id == order.id);
      _availableOrders.insert(0, order);
      _addNotification('New delivery request');
    } else if (type == 'ORDER_READY_FOR_PICKUP') {
      final orderMap = map['order'] is Map
          ? Map<String, dynamic>.from(map['order'] as Map)
          : map;
      final order = OrderModel.fromJson(orderMap);
      if (_activeOrder?.id == order.id) {
        _activeOrder = order;
      }
      _addNotification('Food ready at restaurant!');
    } else if (type == 'INCENTIVE_EARNED') {
      _addNotification('Bonus earned! +₹${map['amount'] ?? ''}');
    }
    notifyListeners();
  }

  Future<void> _loadSurgeStatus() async {
    try {
      final role = await TokenStorage.getRole();
      if (role != 'agent' && role != 'DELIVERY_PARTNER') return;
      _surgeStatus = await AgentService().getSurgeStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _fetchAvailableOrders() async {
    if (_currentCity.trim().isEmpty) {
      _availableOrders = [];
      notifyListeners();
      return;
    }
    try {
      final orders = await OrderService().getAvailableOrders(_currentCity);
      _availableOrders = orders;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to get available orders: $e');
    }
  }

  // ── KYC Form Data ─────────────────────────────────────
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final idNumberController = TextEditingController();
  final licenseNumberController = TextEditingController();
  String vehicleType = 'Bike';
  final vehicleNumberController = TextEditingController();

  void setVehicleType(String type) {
    vehicleType = type;
    notifyListeners();
  }

  Uint8List? profilePhoto;
  Uint8List? aadhaarImage;
  Uint8List? licenseImage;

  Future<void> _loadKYCData() async {
    await refreshKYCStatus();
  }

  // ── Agent Profile Data ────────────────────────────────
  String agentName = '';
  String agentPhone = '';
  String agentEmail = '';
  String agentCity = '';
  String agentFeId = '';
  double agentWalletBalance = 0;

  Future<void> refreshKYCStatus() async {
    if (_currentAgentId.isEmpty) return;
    try {
      final profile = await AgentService().getAgentProfile(_currentAgentId);
      final statusStr = profile['kycStatus'] as String? ?? 'not_submitted';
      
      agentName = profile['name'] ?? '';
      agentPhone = profile['phone'] ?? '';
      agentEmail = profile['email'] ?? '';
      agentCity = profile['city'] ?? '';
      vehicleType = profile['vehicleType'] ?? 'Bike';
      vehicleNumberController.text = profile['vehicleNumber'] ?? '';
      agentFeId = profile['feId'] ?? '';
      agentWalletBalance = (profile['walletBalance'] ?? 0).toDouble();

      switch (statusStr) {
        case 'approved':
          _kycStatus = KYCStatus.approved;
          await refreshEarnings();
          break;
        case 'rejected':
          _kycStatus = KYCStatus.rejected;
          break;
        case 'pending':
          _kycStatus = KYCStatus.pending;
          break;
        default:
          _kycStatus = KYCStatus.notSubmitted;
      }
    } catch (e) {
      _kycStatus = KYCStatus.notSubmitted;
    }
    notifyListeners();
  }

  // ── KYC Actions ──────────────────────────────────────
  Future<void> submitKYC() async {
    try {
      String? profileUrl;
      String? aadhaarUrl;
      String? licenseUrl;
      if (profilePhoto != null) {
        profileUrl = await UploadService().uploadImage(profilePhoto!, 'profile.jpg', type: 'agent');
      }
      if (aadhaarImage != null) {
        aadhaarUrl = await UploadService().uploadImage(aadhaarImage!, 'aadhaar.jpg', type: 'agent');
      }
      if (licenseImage != null) {
        licenseUrl = await UploadService().uploadImage(licenseImage!, 'license.jpg', type: 'agent');
      }
      
      await AgentService().submitKyc({
        'agentId': _currentAgentId,
        'step1': {
          'fullName': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'idNumber': idNumberController.text.trim(),
          'address': _currentCity,
        },
        'step2': {
          'aadhaarPhotoUrl': aadhaarUrl ?? '',
        },
        'step3': {
          'vehicleType': vehicleType,
          'registrationNumber': vehicleNumberController.text.trim(),
          'licenseNumber': licenseNumberController.text.trim(),
          'drivingLicensePhotoUrl': licenseUrl ?? '',
        },
        'step4': {
          'profilePhotoUrl': profileUrl ?? '',
        },
      });
      await refreshKYCStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Error submitting KYC: $e');
    }
  }

  void resetKYC() {
    _kycStatus = KYCStatus.notSubmitted;
    _currentKycStep = 0;
    notifyListeners();
  }

  Future<void> pickImage(String type) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null) {
      final bytes = await _getBytes(result.files.single);
      if (type == 'profile') profilePhoto = bytes;
      if (type == 'aadhaar') aadhaarImage = bytes;
      if (type == 'license') licenseImage = bytes;
      notifyListeners();
    }
  }

  Future<Uint8List?> _getBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (kIsWeb) return null;
    try {
      final ioFile = io.File(file.path!);
      return await ioFile.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  // ── Status ────────────────────────────────────────────
  bool _isOnline = false;
  bool get isOnline => _isOnline;
  double? _currentLatitude;
  double? _currentLongitude;
  String _currentCity = '';
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  String get currentCity => _currentCity;

  // ── Available orders ──────────────────────────────────
  List<OrderModel> _availableOrders = [];
  List<OrderModel> get availableOrders => List.unmodifiable(_availableOrders);

  // ── Active order ──────────────────────────────────────
  OrderModel? _activeOrder;
  OrderModel? get activeOrder => _activeOrder;

  // ── Delivery step tracking ────────────────────────────
  DeliveryStep _currentStep = DeliveryStep.goToRestaurant;
  DeliveryStep get currentStep => _currentStep;
  bool _hasActiveOrder = false;
  bool get hasActiveOrder => _hasActiveOrder;

  // ── Earnings ──────────────────────────────────────────
  double _todayEarnings = 0;
  int _todayDeliveries = 0;
  List<EarningsRecord> _weeklyData = _emptyWeek();
  List<EarningsRecord> get weeklyData => List.unmodifiable(_weeklyData);
  double get todayEarnings => _todayEarnings;
  int get todayDeliveries => _todayDeliveries;
  double get weeklyTotal => _weeklyData.fold(0, (s, r) => s + r.amount);

  Future<void> refreshEarnings() async {
    if (_currentAgentId.isEmpty) return;
    try {
      final data = await AgentService().getEarnings(_currentAgentId);
      final today = data['today'] is Map
          ? Map<String, dynamic>.from(data['today'] as Map)
          : <String, dynamic>{};
      final weekly = (data['weekly'] as List? ?? [])
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            final day = (map['day'] ?? '').toString();
            return EarningsRecord(
              day: day.length > 3 ? day.substring(0, 3) : day,
              amount: (map['amount'] as num? ?? 0).toDouble(),
              deliveries: (map['deliveries'] as num? ?? 0).toInt(),
            );
          })
          .toList();
      _todayEarnings = (today['totalEarnings'] as num? ?? 0).toDouble();
      _todayDeliveries = (today['deliveries'] as num? ?? 0).toInt();
      _weeklyData = weekly.isEmpty ? _emptyWeek() : weekly;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh earnings: $e');
    }
  }

  // ── Timer ─────────────────────────────────────────────
  Timer? _deliveryTimer;
  int _timerSeconds = 0;
  int get timerSeconds => _timerSeconds;

  // ── Notifications ─────────────────────────────────────
  final List<String> _notifications = [];
  List<String> get notifications => List.unmodifiable(_notifications);

  // ── Toggle online/offline ─────────────────────────────
  Future<void> toggleOnline() async {
    _isOnline = !_isOnline;
    try {
      if (_isOnline) {
        await _captureCurrentLocation();
      }
      await AgentService().toggleOnlineStatus(
        _currentAgentId,
        _isOnline,
        latitude: _currentLatitude,
        longitude: _currentLongitude,
      );
      if (_isOnline) {
        _addNotification('You are now Online in $_currentCity');
        WsService.instance.connectPartnerOrders();
      } else {
        _addNotification('You are now Offline');
        _availableOrders = [];
      }
      notifyListeners();
    } catch (e) {
      _isOnline = !_isOnline; // Revert
      debugPrint('Toggle error: $e');
    }
  }

  Future<void> _captureCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      _currentCity = _detectCity(position.latitude, position.longitude);
    } catch (_) {}
  }

  String _detectCity(double latitude, double longitude) {
    final hunsurDistance = Geolocator.distanceBetween(latitude, longitude, 12.3050, 76.2910);
    final krDistance = Geolocator.distanceBetween(latitude, longitude, 12.4219, 76.0200);
    return hunsurDistance <= krDistance ? 'Hunsur' : 'KR Nagar';
  }

  // ── Accept order ──────────────────────────────────────
  Future<void> acceptOrder(OrderModel order) async {
    try {
      final assignmentId = _requestAssignmentId(order);
      _activeAssignment = await OrderService().acceptAssignment(assignmentId);
      await WsService.instance.connectPartnerLocation();
      _activeOrder = order;
      _hasActiveOrder = true;
      _availableOrders.remove(order);
      _currentStep = DeliveryStep.goToRestaurant;
      _startTimer();
      _addNotification('Order ${order.id} accepted!');
      notifyListeners();
    } catch (e) {
      debugPrint('Accept error: $e');
    }
  }

  // ── Reject order ──────────────────────────────────────
  void rejectOrder(OrderModel order) {
    OrderService().rejectAssignment(_requestAssignmentId(order), reason: 'Not available');
    _availableOrders.remove(order);
    _addNotification('Order ${order.id} rejected');
    notifyListeners();
  }

  // ── Advance delivery step ─────────────────────────────
  Future<void> advanceStep() async {
    if (_activeOrder == null) return;
    try {
      switch (_currentStep) {
        case DeliveryStep.goToRestaurant:
          await OrderService().reachedRestaurant(_currentAssignmentId);
          _currentStep = DeliveryStep.pickupOrder;
          _addNotification('Arrived at Restaurant');
          break;
        case DeliveryStep.pickupOrder:
          await OrderService().pickedUp(_currentAssignmentId);
          _currentStep = DeliveryStep.navigateToCustomer;
          _addNotification('Order picked up! Heading to customer');
          break;
        case DeliveryStep.navigateToCustomer:
          await OrderService().reachedCustomer(_currentAssignmentId);
          _currentStep = DeliveryStep.delivered;
          _addNotification('Arrived at customer location');
          break;
        case DeliveryStep.delivered:
          return;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Step update error: $e');
    }
  }

  // ── Complete delivery ─────────────────────────────────
  void _completeDelivery() {
    if (_activeOrder == null) return;
    _addNotification('🎉 Delivery complete!');
    _stopTimer();
    _activeOrder = null;
    _activeAssignment = null;
    _hasActiveOrder = false;
    _currentStep = DeliveryStep.goToRestaurant;
    refreshEarnings();
    _fetchAvailableOrders();
    notifyListeners();
  }

  String _requestAssignmentId(OrderModel order) {
    return (_latestRequest?['id'] ??
            _latestRequest?['assignment_id'] ??
            _latestRequest?['assignmentId'] ??
            order.id)
        .toString();
  }

  String get _currentAssignmentId {
    return (_activeAssignment?['id'] ??
            _activeAssignment?['assignment_id'] ??
            _activeAssignment?['assignmentId'] ??
            _latestRequest?['id'] ??
            _latestRequest?['assignment_id'] ??
            _activeOrder?.id ??
            '')
        .toString();
  }

  Future<bool> confirmDeliveryOtp(String otp) async {
    if (_activeOrder == null) return false;
    try {
      _activeAssignment = await OrderService().deliverAssignment(
        _currentAssignmentId,
        otp: otp,
      );
      _completeDelivery();
      return true;
    } catch (e) {
      _addNotification('Wrong OTP');
      notifyListeners();
      return false;
    }
  }

  void _startTimer() {
    _timerSeconds = 0;
    _deliveryTimer?.cancel();
    _deliveryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _timerSeconds++;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _deliveryTimer?.cancel();
    _timerSeconds = 0;
  }

  void _addNotification(String msg) {
    _notifications.insert(0, msg);
    if (_notifications.length > 10) _notifications.removeLast();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _assignmentSub?.cancel();
    _surgeTimer?.cancel();
    WsService.instance.disconnectPartnerOrders();
    WsService.instance.disconnectPartnerLocation();
    _deliveryTimer?.cancel();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    idNumberController.dispose();
    licenseNumberController.dispose();
    vehicleNumberController.dispose();
    super.dispose();
  }

  String get stepLabel {
    switch (_currentStep) {
      case DeliveryStep.goToRestaurant: return 'Go to Restaurant';
      case DeliveryStep.pickupOrder: return 'Pick Up Order';
      case DeliveryStep.navigateToCustomer: return 'Navigate to Customer';
      case DeliveryStep.delivered: return 'Mark as Delivered';
    }
  }

  String get nextStepButtonLabel {
    switch (_currentStep) {
      case DeliveryStep.goToRestaurant: return 'Arrived at Restaurant';
      case DeliveryStep.pickupOrder: return 'Order Picked Up';
      case DeliveryStep.navigateToCustomer: return 'Arrived at Customer';
      case DeliveryStep.delivered: return 'Confirm Delivery ✓';
    }
  }

  IconData get stepIcon {
    switch (_currentStep) {
      case DeliveryStep.goToRestaurant: return Icons.directions_bike;
      case DeliveryStep.pickupOrder: return Icons.takeout_dining;
      case DeliveryStep.navigateToCustomer: return Icons.navigation;
      case DeliveryStep.delivered: return Icons.check_circle;
    }
  }

  int get stepIndex => DeliveryStep.values.indexOf(_currentStep);

  String get formattedTimer {
    final m = (_timerSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_timerSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
