import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurants_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class CustomerHome extends ConsumerStatefulWidget {
  const CustomerHome({super.key});

  @override
  ConsumerState<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends ConsumerState<CustomerHome> {
  final List<String> categories = ['Meals', 'Tiffin', 'Snacks', 'Sweets', 'Beverages'];
  String selectedCategory = 'Meals';

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final restaurants = ref.watch(restaurantsProvider);
    final town = ref.watch(authProvider).valueOrNull?.town;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          backgroundColor: Colors.black,
          title: Image.asset('assets/images/bitex99_logo.png', height: 22),
          actions: [
            Container(
              margin: EdgeInsets.only(right: R.wp(2.0)),
              padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(0.6)),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: R.wp(3.8), color: Colors.red),
                  SizedBox(width: R.wp(1.0)),
                  Text(town?.isNotEmpty == true ? town! : 'KR Nagar',
                      style: TextStyle(fontSize: R.sp(3.5), color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.search, size: R.wp(6.5), color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(restaurantsProvider.notifier).refreshRestaurants(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBannerCarousel(),
              SizedBox(height: R.hp(2.5)),
              _buildCategoryRow(),
              SizedBox(height: R.hp(2.5)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.wp(5.0)),
                child: Text('Restaurants near you',
                    style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: R.hp(1.5)),
              restaurants.when(
                data: (items) => items.isEmpty
                    ? Center(child: Text('No restaurants yet in your town!', style: TextStyle(fontSize: R.sp(4.0))))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _buildRestaurantCard(items[index]),
                      ),
                error: (error, _) => Center(child: Text(error.toString())),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
              SizedBox(height: R.hp(12.0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: R.hp(24.0),
      child: PageView(
        children: [
          _buildBannerItem('Today\'s Specials', 'Fresh & Hot Meals', Colors.orange.shade100),
          _buildBannerItem('Local Favorites', 'Authentic Taste', Colors.deepOrange.shade50),
        ],
      ),
    );
  }

  Widget _buildBannerItem(String title, String subtitle, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.wp(5.0)),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(R.wp(3.5))),
      child: Stack(
        children: [
          Positioned(
            right: -R.wp(5.0),
            bottom: -R.hp(2.0),
            child: Icon(Icons.fastfood, size: R.wp(35.0), color: Colors.white.withOpacity(0.3)),
          ),
          Padding(
            padding: EdgeInsets.all(R.wp(5.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: R.sp(5.5), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: R.hp(0.8)),
                Text(subtitle, style: TextStyle(fontSize: R.sp(4.0), color: AppTheme.textColor)),
                const Spacer(),
                ElevatedButton(onPressed: () {}, child: Text('Order Now', style: TextStyle(fontSize: R.sp(4.0)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: R.hp(4.8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0)),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final selected = selectedCategory == categories[index];
          return Padding(
            padding: EdgeInsets.only(right: R.wp(2.5)),
            child: ChoiceChip(
              label: Text(categories[index],
                  style: TextStyle(fontSize: R.sp(3.8), color: selected ? Colors.white : AppTheme.textColor)),
              selected: selected,
              onSelected: (_) => setState(() => selectedCategory = categories[index]),
              selectedColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantModel restaurant) {
    return GestureDetector(
      onTap: () => context.go('/restaurant/${restaurant.id}/menu', extra: restaurant),
      child: Container(
        height: R.hp(26.0),
        margin: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(1.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(R.wp(3.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(R.wp(3.5)),
                    topRight: Radius.circular(R.wp(3.5)),
                  ),
                ),
                child: Center(child: Icon(Icons.restaurant, size: R.wp(12.0), color: Colors.grey)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(restaurant.shopName,
                              style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(0.3)),
                          decoration: BoxDecoration(
                            color: restaurant.isOpen ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            restaurant.isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: restaurant.isOpen ? Colors.green : Colors.red,
                              fontSize: R.sp(3.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer, size: R.wp(4.0), color: AppTheme.greyColor),
                        SizedBox(width: R.wp(1.0)),
                        Text('${restaurant.avgDeliveryTime} min', style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor)),
                        SizedBox(width: R.wp(4.0)),
                        Icon(Icons.star, size: R.wp(4.0), color: Colors.orange),
                        SizedBox(width: R.wp(1.0)),
                        Text(restaurant.rating.toStringAsFixed(1), style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor)),
                        SizedBox(width: R.wp(4.0)),
                        Expanded(
                          child: Text(restaurant.cuisineType,
                              style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
