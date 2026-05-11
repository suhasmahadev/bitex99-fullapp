import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_storage.dart';
import '../models/models.dart';
import '../services/restaurant_service.dart';
import 'auth_provider.dart';

final restaurantsProvider =
    AsyncNotifierProvider<RestaurantsController, List<RestaurantModel>>(
  RestaurantsController.new,
);

class RestaurantsController extends AsyncNotifier<List<RestaurantModel>> {
  final _service = RestaurantService();

  @override
  Future<List<RestaurantModel>> build() async {
    final user = ref.watch(authProvider).valueOrNull;
    final town = user?.town.isNotEmpty == true
        ? user!.town
        : LocalStorage.preferences.get('town', defaultValue: 'KR Nagar').toString();
    final cached = LocalStorage.restaurants.get(town);
    if (cached is List) {
      state = AsyncData(cached
          .whereType<Map>()
          .map((item) => RestaurantModel.fromJson(Map<String, dynamic>.from(item)))
          .toList());
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return state.valueOrNull ?? [];
    }
    return refreshRestaurants(town: town);
  }

  Future<List<RestaurantModel>> refreshRestaurants({String? town}) async {
    final resolvedTown = town ??
        ref.read(authProvider).valueOrNull?.town ??
        LocalStorage.preferences.get('town', defaultValue: 'KR Nagar').toString();
    final restaurants = await _service.getRestaurantsByTown(resolvedTown);
    await LocalStorage.restaurants.put(
      resolvedTown,
      restaurants.map((restaurant) => restaurant.toMap()..['id'] = restaurant.id).toList(),
    );
    state = AsyncData(restaurants);
    return restaurants;
  }
}
