import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/local_storage.dart';
import '../../core/token_storage.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/restaurants_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ws_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    unawaited(_hydrate());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final started = DateTime.now();

    // ── Remember Me gate ───────────────────────────────────────────────────
    // If the user explicitly unchecked "Remember me", always show login on
    // cold start regardless of whether a token was stored in memory.
    final rememberMe =
        LocalStorage.preferences.get('remember_me', defaultValue: false) == true;
    if (!rememberMe) {
      // Clear any lingering token so authProvider resolves to null
      await TokenStorage.clearAll();
    }
    // ──────────────────────────────────────────────────────────────────────

    final user = await ref.read(authProvider.future);
    if (!mounted) return;
    if (user == null) {
      context.go('/login');
      return;
    }
    await WsService().initForRole(user.role);
    final legacyRole = _legacyRoleFor(user.role);
    if (legacyRole != null) {
      context.read<UserProvider>().login(
            uid: user.uid,
            name: user.name,
            phone: user.phone,
            role: legacyRole,
            town: user.town,
          );
      context.read<ThemeProvider>().setRoleTheme(legacyRole);
    }

    await Future.wait([
      ref.read(cartProvider.future).catchError((_) => null),
      ref.read(ordersProvider.future).catchError((_) => null),
      ref.read(addressProvider.future).catchError((_) => null),
      ref.read(restaurantsProvider.future).catchError((_) => null),
    ]).timeout(const Duration(seconds: 2), onTimeout: () => []);

    final elapsed = DateTime.now().difference(started);
    if (elapsed < const Duration(milliseconds: 700)) {
      await Future.delayed(const Duration(milliseconds: 700) - elapsed);
    }
    if (!mounted) return;

    if (user.role == 'admin') {
      context.go('/admin');
      return;
    }
    if (user.role == 'restaurant') {
      context.go('/restaurant-admin');
      return;
    }
    if (user.role == 'agent') {
      context.go('/delivery');
      return;
    }
    final shown = LocalStorage.preferences
            .get('notification_onboarding_shown', defaultValue: false) ==
        true;
    context.go(shown ? '/home/restaurants' : '/notifications-onboarding');
  }

  UserRole? _legacyRoleFor(String role) {
    switch (role) {
      case 'customer':
        return UserRole.customer;
      case 'restaurant':
        return UserRole.restaurantPartner;
      case 'agent':
        return UserRole.deliveryAgent;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/bitex99_logo.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your Town. Your Food.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
