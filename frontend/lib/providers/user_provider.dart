import 'package:flutter/material.dart';

/// Enum for the three user roles in the app.
enum UserRole { customer, restaurantPartner, deliveryAgent }

/// Enum for KYC Status
enum KycStatus { none, pending, approved, rejected }

/// Extension to get display label and route for each role.
extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.restaurantPartner:
        return 'Restaurant Partner';
      case UserRole.deliveryAgent:
        return 'Delivery Agent';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.customer:
        return Icons.person_outline;
      case UserRole.restaurantPartner:
        return Icons.storefront_outlined;
      case UserRole.deliveryAgent:
        return Icons.delivery_dining_outlined;
    }
  }

  String get route {
    switch (this) {
      case UserRole.customer:
        return '/home';
      case UserRole.restaurantPartner:
        return '/partner';
      case UserRole.deliveryAgent:
        return '/delivery';
    }
  }
}

/// UserProvider — stores auth state (name, phone, role) across the app.
class UserProvider extends ChangeNotifier {
  String _uid = '';
  String _name = '';
  String _phone = '';
  String _town = '';
  UserRole? _role;
  bool _isLoggedIn = false;

  // Agent KYC state
  KycStatus _agentKycStatus = KycStatus.none;
  String? _agentKycRejectionReason;

  // ── Getters ──────────────────────────────────────────
  String get uid => _uid;
  String get name => _name;
  String get phone => _phone;
  String get town => _town;
  UserRole? get role => _role;
  bool get isLoggedIn => _isLoggedIn;
  String get roleLabel => _role?.label ?? '';

  KycStatus get agentKycStatus => _agentKycStatus;
  String? get agentKycRejectionReason => _agentKycRejectionReason;

  // ── Actions ──────────────────────────────────────────

  /// Simulate login — stores user data and marks as logged in.
  void login({
    String uid = '',
    required String name,
    required String phone,
    required UserRole role,
    String town = '',
  }) {
    _uid = uid;
    _name = name;
    _phone = phone;
    _town = town;
    _role = role;
    _isLoggedIn = true;
    notifyListeners();
  }

  void setTown(String town) {
    _town = town;
    notifyListeners();
  }

  void setRole(UserRole? role) {
    _role = role;
    notifyListeners();
  }

  void updateAgentKycStatus(KycStatus status, {String? reason}) {
    _agentKycStatus = status;
    _agentKycRejectionReason = reason;
    notifyListeners();
  }

  void logout() {
    _uid = '';
    _name = '';
    _phone = '';
    _town = '';
    _role = null;
    _isLoggedIn = false;
    _agentKycStatus = KycStatus.none;
    _agentKycRejectionReason = null;
    notifyListeners();
  }
}
