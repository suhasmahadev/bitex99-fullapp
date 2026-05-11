import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  UserRole _currentRole = UserRole.customer;
  ThemeData _currentThemeData = AppTheme.lightTheme; // default customer theme

  UserRole get currentRole => _currentRole;
  ThemeData get currentThemeData => _currentThemeData;

  ThemeProvider() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final roleIndex = prefs.getInt('saved_role_theme');
    if (roleIndex != null && roleIndex >= 0 && roleIndex < UserRole.values.length) {
      _currentRole = UserRole.values[roleIndex];
      _updateThemeData();
    }
  }

  void setRoleTheme(UserRole role) async {
    if (_currentRole == role) return;
    _currentRole = role;
    _updateThemeData();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_role_theme', role.index);
  }

  void _updateThemeData() {
    switch (_currentRole) {
      case UserRole.customer:
        _currentThemeData = AppTheme.customerTheme;
        break;
      case UserRole.restaurantPartner:
        _currentThemeData = AppTheme.restaurantTheme;
        break;
      case UserRole.deliveryAgent:
        _currentThemeData = AppTheme.deliveryTheme;
        break;
    }
  }
}
