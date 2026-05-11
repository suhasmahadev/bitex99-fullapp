import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/token_storage.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import '../../services/restaurant_service.dart';
import '../../models/models.dart';
import '../onboarding/login_screen.dart';
import 'restaurant_main.dart';

class RestaurantWaitingScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const RestaurantWaitingScreen({super.key, required this.restaurant});

  @override
  State<RestaurantWaitingScreen> createState() =>
      _RestaurantWaitingScreenState();
}

class _RestaurantWaitingScreenState extends State<RestaurantWaitingScreen> {
  bool _isApproved = false;
  bool _isProcessing = false; // guard against duplicate approval runs
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _listenForApproval();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _listenForApproval() {
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) async {
        if (!mounted || _isProcessing) return;

        try {
          final restaurant = await RestaurantService()
            .getRestaurantById(widget.restaurant.id);
            
          if (restaurant?.status == 'active' || restaurant?.status == 'approved') {
            _isProcessing = true;
            _timer?.cancel();
            if (mounted) {
              setState(() => _isApproved = true);
            }
          }
        } catch (e) {
          debugPrint('Error listening to restaurant status: $e');
        }
      }
    );
  }

  void _navigateToMenu() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => const RestaurantMain(initialIndex: 1)),
      (route) => false,
    );
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => const RestaurantMain(initialIndex: 0)),
      (route) => false,
    );
  }

  Future<void> _backToLogin() async {
    await TokenStorage.clearAll();
    if (!mounted) return;
    context.read<UserProvider>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(town: '')),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            Text('Application Status', style: TextStyle(fontSize: R.sp(4.5))),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToLogin,
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(R.wp(8.0)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isApproved) ...[
                CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                SizedBox(height: R.hp(4.0)),
                Text(
                  'Your application is under review',
                  style: TextStyle(
                      fontSize: R.sp(5.5), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: R.hp(2.0)),
                Text(
                  'Please wait while we verify your details. This usually takes a few moments.',
                  style: TextStyle(
                      fontSize: R.sp(4.0), color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Icon(Icons.check_circle, color: Colors.green, size: R.wp(20.0)),
                SizedBox(height: R.hp(4.0)),
                Text(
                  'Your restaurant is approved!',
                  style: TextStyle(
                      fontSize: R.sp(5.5), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: R.hp(2.0)),
                Text(
                  'You can now set up your menu and start receiving orders.',
                  style: TextStyle(
                      fontSize: R.sp(4.0), color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: R.hp(6.0)),
                SizedBox(
                  width: double.infinity,
                  height: R.hp(7.0),
                  child: ElevatedButton(
                    onPressed: _navigateToMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(R.wp(3.0))),
                    ),
                    child: Text('Setup Your Menu',
                        style: TextStyle(
                            fontSize: R.sp(4.5), color: Colors.white)),
                  ),
                ),
                SizedBox(height: R.hp(2.0)),
                SizedBox(
                  width: double.infinity,
                  height: R.hp(7.0),
                  child: OutlinedButton(
                    onPressed: _navigateToDashboard,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(R.wp(3.0))),
                    ),
                    child: Text('Go to Dashboard',
                        style: TextStyle(
                            fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

