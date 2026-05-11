import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure JWT token storage — replaces FirebaseAuth credential persistence.
class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'bitex_token';
  static const _refreshTokenKey = 'bitex_refresh_token';
  static const _userKey = 'bitex_user';
  static const _roleKey = 'bitex_role';

  static String? _memoryToken;
  static String? _memoryRefreshToken;
  static String? _memoryUser;
  static String? _memoryRole;

  static Future<void> saveToken(String token) async {
    _memoryToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    if (_memoryToken != null && _memoryToken!.isNotEmpty) return _memoryToken;
    _memoryToken = await _storage.read(key: _tokenKey);
    return _memoryToken;
  }

  static Future<void> saveRefreshToken(String token) async {
    _memoryRefreshToken = token;
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    if (_memoryRefreshToken != null && _memoryRefreshToken!.isNotEmpty) {
      return _memoryRefreshToken;
    }
    _memoryRefreshToken = await _storage.read(key: _refreshTokenKey);
    return _memoryRefreshToken;
  }

  static Future<void> saveUser(String userJson) async {
    _memoryUser = userJson;
    await _storage.write(key: _userKey, value: userJson);
  }

  static Future<String?> getUser() async {
    if (_memoryUser != null && _memoryUser!.isNotEmpty) return _memoryUser;
    _memoryUser = await _storage.read(key: _userKey);
    return _memoryUser;
  }

  static Future<void> saveRole(String role) async {
    _memoryRole = role;
    await _storage.write(key: _roleKey, value: role);
  }

  static Future<String?> getRole() async {
    if (_memoryRole != null && _memoryRole!.isNotEmpty) return _memoryRole;
    _memoryRole = await _storage.read(key: _roleKey);
    return _memoryRole;
  }

  static Future<void> clearAll() async {
    _memoryToken = null;
    _memoryRefreshToken = null;
    _memoryUser = null;
    _memoryRole = null;
    await _storage.deleteAll();
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
