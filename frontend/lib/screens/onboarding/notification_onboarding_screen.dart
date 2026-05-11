import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_constants.dart';
import '../../core/local_storage.dart';

class NotificationOnboardingScreen extends StatefulWidget {
  const NotificationOnboardingScreen({super.key});

  @override
  State<NotificationOnboardingScreen> createState() =>
      _NotificationOnboardingScreenState();
}

class _NotificationOnboardingScreenState
    extends State<NotificationOnboardingScreen> {
  bool _busy = false;

  Future<void> _finish({required bool enable}) async {
    setState(() => _busy = true);
    if (enable) {
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          final token = await messaging.getToken();
          if (token != null) {
            await apiClient.client.post(
              ApiConstants.notificationsRegister,
              data: {'fcm_token': token, 'platform': 'android'},
            );
          }
        }
      } on DioException {
        // Notification registration should never block entering the app.
      } catch (_) {}
    }
    await LocalStorage.preferences.put('notification_onboarding_shown', true);
    if (mounted) context.go('/home/restaurants');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Icon(Icons.notifications_active, size: 88),
              ),
              const SizedBox(height: 28),
              const Text(
                'Stay updated on your orders',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const _Benefit(text: 'Order confirmations'),
              const _Benefit(text: 'Delivery updates'),
              const _Benefit(text: 'Offers'),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : () => _finish(enable: true),
                child: const Text('Enable Notifications'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _finish(enable: false),
                child: const Text('Not Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final String text;
  const _Benefit({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
