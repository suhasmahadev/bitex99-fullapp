import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'customer_home.dart';
import '../onboarding/login_screen.dart';
import '../../core/token_storage.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';

class CustomerMain extends StatefulWidget {
  const CustomerMain({super.key});

  @override
  State<CustomerMain> createState() => _CustomerMainState();
}

class _CustomerMainState extends State<CustomerMain> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const CustomerHome(),
    const _EmptyCartPlaceholder(),
    const _EmptyOrdersPlaceholder(),
  ];

  Future<void> _goToLogin() async {
    await TokenStorage.clearAll();
    if (!mounted) return;
    context.read<UserProvider>().logout();
    context.go('/login');
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
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCartPlaceholder extends StatelessWidget {
  const _EmptyCartPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Browse restaurants and add items', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersPlaceholder extends StatelessWidget {
  const _EmptyOrdersPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active orders', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Place an order to track it here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

