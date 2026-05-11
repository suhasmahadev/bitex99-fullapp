import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/menu_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/global_cart_bar.dart';

class RestaurantDetail extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  const RestaurantDetail({super.key, required this.restaurant});

  @override
  ConsumerState<RestaurantDetail> createState() => _RestaurantDetailState();
}

class _RestaurantDetailState extends ConsumerState<RestaurantDetail> {
  List<MenuItemModel> _menuItems = [];
  bool _isLoadingMenu = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final items = await MenuService().getMenuForRestaurant(widget.restaurant.id);
      if (mounted) {
        setState(() {
          _menuItems = items;
          _isLoadingMenu = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMenu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final cart = ref.watch(cartProvider).valueOrNull ?? CartState.empty;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(restaurant: widget.restaurant),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.0)),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: R.wp(5.0)),
                      SizedBox(width: R.wp(1.5)),
                      Text('FSSAI Licensed',
                          style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor)),
                      const Spacer(),
                      Icon(Icons.star, color: Colors.orange, size: R.wp(5.0)),
                      SizedBox(width: R.wp(1.0)),
                      Text(widget.restaurant.rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor)),
                    ],
                  ),
                ),
                Divider(height: R.hp(1.0)),
                Padding(
                  padding: EdgeInsets.all(R.wp(5.0)),
                  child: Text('Menu',
                      style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600)),
                ),
                if (_isLoadingMenu)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._menuItems.map((item) => _buildMenuItem(item, cart)),
                SizedBox(height: R.hp(12.0)),
              ],
            ),
          ),
          const Positioned(bottom: 80, left: 16, right: 16, child: GlobalCartBar()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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

  Widget _buildMenuItem(MenuItemModel item, CartState cart) {
    final count = cart.items
        .where((cartItem) => cartItem.menuItemId == item.id)
        .fold<int>(0, (_, cartItem) => cartItem.quantity);
    final isSoldOut = !item.available;

    return Opacity(
      opacity: isSoldOut ? 0.5 : 1.0,
      child: Container(
        height: R.hp(11.0),
        margin: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(0.8)),
        padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(R.wp(3.5)),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.isSpecial)
                    Text('Special',
                        style: TextStyle(fontSize: R.sp(3.0), color: Colors.red, fontWeight: FontWeight.bold)),
                  Text(item.name,
                      style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('₹ ${item.price.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: R.sp(4.2), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            if (isSoldOut)
              Text('Sold Out',
                  style: TextStyle(fontSize: R.sp(3.5), color: Colors.red, fontWeight: FontWeight.bold))
            else if (count == 0)
              SizedBox(
                width: R.wp(22.0),
                height: R.hp(5.0),
                child: OutlinedButton(
                  onPressed: () => ref.read(cartProvider.notifier).addItem(item.id, 1),
                  child: Text('Add',
                      style: TextStyle(fontSize: R.sp(4.0), color: Theme.of(context).colorScheme.primary)),
                ),
              )
            else
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle,
                        color: Theme.of(context).colorScheme.primary, size: R.wp(6.5)),
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.id, count > 1 ? count - 1 : 0),
                  ),
                  Text('$count',
                      style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.add_circle,
                        color: Theme.of(context).colorScheme.primary, size: R.wp(6.5)),
                    onPressed: () =>
                        ref.read(cartProvider.notifier).updateQuantity(item.id, count + 1),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RestaurantModel restaurant;
  const _Header({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: R.hp(28.0),
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary,
      child: Stack(
        children: [
          Center(child: Icon(Icons.restaurant, size: R.wp(20.0), color: Colors.white)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
            ),
          ),
          Positioned(
            top: R.hp(5.0),
            left: R.wp(4.0),
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: R.wp(6.5)),
                onPressed: () => context.go('/home/restaurants'),
              ),
            ),
          ),
          Positioned(
            bottom: R.hp(2.0),
            left: R.wp(5.0),
            right: R.wp(5.0),
            child: Text(
              restaurant.shopName,
              style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
