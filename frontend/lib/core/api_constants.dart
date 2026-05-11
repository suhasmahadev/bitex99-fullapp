import 'package:flutter/foundation.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SETUP REQUIRED BEFORE RUNNING ON REAL DEVICE:
// 1. Connect phone and laptop to same WiFi network
// 2. Run: ipconfig (Windows) or ifconfig (Mac/Linux)
// 3. Find your IPv4 address (e.g., 192.168.1.105)
// 4. Replace the IP below with your actual IP
// 5. Run backend with: uvicorn app.main:app
//    --host 0.0.0.0 --port 8000
//
// For Flutter Web (Chrome): uses 'localhost' automatically
// For Android EMULATOR (not real device): use 10.0.2.2
// For iOS SIMULATOR (not real device): use 127.0.0.1
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// ─────────────────────────────────────────────────────────────────────────
/// API Constants — BiteX99
/// ─────────────────────────────────────────────────────────────────────────
///
/// Platform-aware base URL selection:
///   • Flutter Web (Chrome)       → 'localhost'   (auto-detected via kIsWeb)
///   • Android Emulator (AVD)     → '10.0.2.2'
///   • Real Android/iOS on WiFi   → your machine's IPv4 (edit _deviceIP)
///
class ApiConstants {
  // ── Real-device override (only used for non-web, non-emulator) ──────────
  static const String _deviceIP = '10.156.203.215';
  static const String _configuredIP = String.fromEnvironment('BITEX_API_HOST');
  static String get baseIP {
    if (_configuredIP.isNotEmpty) return _configuredIP;
    return kIsWeb ? 'localhost' : _deviceIP;
  }

  static const String basePort = '8000';

  // ── Derived base URLs ────────────────────────────────────────────────────
  static String get apiBase => 'http://$baseIP:$basePort/api/flutter/v1';
  static String get wsBase  => 'ws://$baseIP:$basePort/api/v1/ws';
  static String get uploadBase => 'http://$baseIP:$basePort/uploads';

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // ── Users ────────────────────────────────────────────────────────────────
  static const String userProfile = '/users';
  static const String me = '/users/me';

  // ── Restaurants ──────────────────────────────────────────────────────────
  static const String restaurants = '/restaurants';

  // ── Orders ───────────────────────────────────────────────────────────────
  static const String cart = '/cart';
  static const String cartAdd = '/cart/add';
  static const String cartUpdateQuantity = '/cart/update-quantity';
  static const String cartClear = '/cart/clear';
  static const String cartValidate = '/cart/validate';
  static const String orders = '/orders';
  static const String addresses = '/addresses';
  static const String notificationsRegister = '/notifications/register';

  // ── Agents ───────────────────────────────────────────────────────────────
  static const String agentKyc = '/agents/kyc';
  static const String agentKycStatus = '/agents';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminRestaurants = '/admin/restaurants';
  static const String adminAgents = '/admin/agents';

  // ── Upload ───────────────────────────────────────────────────────────────
  static const String upload = '/upload/image';

  // ── Config ───────────────────────────────────────────────────────────────
  static const String config = '/config';
}
