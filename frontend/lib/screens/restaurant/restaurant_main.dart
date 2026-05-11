import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'restaurant_dashboard.dart';
import 'menu_management.dart';
import '../onboarding/login_screen.dart';
import '../../core/token_storage.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';

class RestaurantMain extends StatefulWidget {
  final int initialIndex;
  const RestaurantMain({super.key, this.initialIndex = 0});

  @override
  State<RestaurantMain> createState() => _RestaurantMainState();
}

class _RestaurantMainState extends State<RestaurantMain> {
  late int _currentIndex = widget.initialIndex;
  final List<Widget> _screens = [
    const RestaurantDashboard(),
    const MenuManagement(),
  ];

  Future<void> _goToLogin() async {
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        _goToLogin();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: SizedBox(
          height: R.hp(9.0),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            iconSize: R.wp(7.0),
            selectedFontSize: R.sp(3.0),
            unselectedFontSize: R.sp(3.0),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Menu'),
            ],
          ),
        ),
      ),
    );
  }
}
