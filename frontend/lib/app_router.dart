import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/local_storage.dart';
import 'core/navigation.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart';
import 'providers/orders_provider.dart';
import 'screens/agent/delivery_dashboard_page.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/customer/cart_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/customer/order_tracking.dart';
import 'screens/customer/restaurant_detail.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/notification_onboarding_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/restaurant/restaurant_main.dart';
import 'screens/restaurant/restaurant_partner_page.dart';
import 'screens/restaurant/restaurant_waiting_screen.dart';
import 'services/restaurant_service.dart';
import 'widgets/global_cart_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final user = auth.valueOrNull;
      final path = state.uri.path;
      final isLoading = auth.isLoading && user == null;
      if (isLoading) return null;
      if (path == '/splash') return null;
      if (path.startsWith('/home') ||
          path.startsWith('/delivery') ||
          path == '/checkout' ||
          path.startsWith('/order') ||
          path.startsWith('/addresses')) {
        if (user == null) return '/login';
      }
      if (user?.role == 'agent' && path.startsWith('/home')) {
        return '/delivery';
      }
      if (path.startsWith('/delivery') && user != null && user.role != 'agent') {
        if (user.role == 'restaurant') return '/restaurant-admin';
        if (user.role == 'admin') return '/admin';
        return '/home/restaurants';
      }
      if (path == '/admin' && user?.role != 'admin') {
        return '/home/restaurants';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen(town: '')),
      GoRoute(
        path: '/notifications-onboarding',
        builder: (_, __) => const NotificationOnboardingScreen(),
      ),
      GoRoute(
        path: '/home/restaurants',
        builder: (_, __) => const _CustomerShell(index: 0),
      ),
      GoRoute(
        path: '/home/cart',
        builder: (_, __) => const _CustomerShell(index: 1),
      ),
      GoRoute(
        path: '/home/orders',
        builder: (_, __) => const _CustomerShell(index: 2),
      ),
      GoRoute(
        path: '/home/profile',
        builder: (_, __) => const _CustomerShell(index: 3),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (_, state) {
          final restaurant = state.extra;
          if (restaurant is! RestaurantModel) return const CustomerHome();
          return RestaurantDetail(restaurant: restaurant);
        },
      ),
      GoRoute(
        path: '/restaurant/:id/menu',
        builder: (_, state) {
          final restaurant = state.extra;
          if (restaurant is! RestaurantModel) return const CustomerHome();
          return RestaurantDetail(restaurant: restaurant);
        },
      ),
      GoRoute(path: '/checkout', builder: (_, __) => const _CustomerShell(index: 1)),
      GoRoute(
        path: '/order/:id/tracking',
        builder: (_, state) => OrderTracking(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/addresses', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/address/pick', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPanel()),
      GoRoute(path: '/delivery', builder: (_, __) => const DeliveryDashboardPage()),
      GoRoute(path: '/restaurant-admin', builder: (_, __) => const _RestaurantGate()),
    ],
  );
});

class _RestaurantGate extends ConsumerStatefulWidget {
  const _RestaurantGate();

  @override
  ConsumerState<_RestaurantGate> createState() => _RestaurantGateState();
}

class _RestaurantGateState extends ConsumerState<_RestaurantGate> {
  Future<RestaurantModel?>? _restaurantFuture;
  String? _phone;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return const LoginScreen(town: '');
    }
    if (_restaurantFuture == null || _phone != user.phone) {
      _phone = user.phone;
      _restaurantFuture = RestaurantService().getRestaurantById(user.phone);
    }
    return FutureBuilder<RestaurantModel?>(
      future: _restaurantFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const RestaurantPartnerPage();
        }
        final restaurant = snapshot.data!;
        if (restaurant.status == 'active') {
          return const RestaurantMain();
        }
        return RestaurantWaitingScreen(restaurant: restaurant);
      },
    );
  }
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

class _CustomerShell extends StatefulWidget {
  final int index;
  const _CustomerShell({required this.index});

  @override
  State<_CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<_CustomerShell> {
  late int _index = widget.index;
  final _screens = const [
    CustomerHome(),
    CartScreen(),
    _OrdersTab(),
    _ProfileTab(),
  ];

  @override
  void didUpdateWidget(covariant _CustomerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _index) _index = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    final hideCart = _index == 1;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          if (!hideCart)
            const Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: GlobalCartBar(),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          final paths = [
            '/home/restaurants',
            '/home/cart',
            '/home/orders',
            '/home/profile',
          ];
          context.go(paths[index]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  Future<void> _cancelOrder(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('You can cancel until preparation starts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(ordersProvider.notifier)
          .cancelOrder(order.id, 'Cancelled by customer');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: orders.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No orders yet'))
            : RefreshIndicator(
                onRefresh: () => ref.read(ordersProvider.notifier).refreshOrders(),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final order = items[index];
                    final canCancel = order.status == 'received' ||
                        order.status == 'confirmed';
                    return ListTile(
                      title: Text('Order #${order.id.substring(0, 6)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(order.status),
                          if (canCancel)
                            TextButton(
                              onPressed: () => _cancelOrder(context, ref, order),
                              child: const Text('Cancel order'),
                            ),
                        ],
                      ),
                      trailing: Text('₹${order.totalAmount.toStringAsFixed(0)}'),
                      onTap: () => context.go('/order/${order.id}/tracking'),
                    );
                  },
                ),
              ),
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(title: Text(user?.name ?? 'Guest'), subtitle: Text(user?.phone ?? '')),
          ListTile(title: const Text('Town'), subtitle: Text(user?.town ?? 'KR Nagar')),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
