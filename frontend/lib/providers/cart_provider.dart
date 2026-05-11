import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../models/models.dart';
import '../services/cart_service.dart';
import '../widgets/cart_conflict_dialog.dart';
import 'auth_provider.dart';

final cartProvider =
    AsyncNotifierProvider<CartController, CartState>(CartController.new);

class CartController extends AsyncNotifier<CartState> {
  final _service = CartService();

  @override
  Future<CartState> build() async {
    ref.watch(authProvider);
    final cached = LocalStorage.cart.get('state');
    if (cached is Map) {
      state = AsyncData(CartState.fromJson(Map<String, dynamic>.from(cached)));
    }
    if (ref.read(authProvider).valueOrNull == null) {
      return state.valueOrNull ?? CartState.empty;
    }
    try {
      final fresh = await _service.getCart();
      await LocalStorage.cart.put('state', fresh.toJson());
      return fresh;
    } catch (_) {
      return state.valueOrNull ?? CartState.empty;
    }
  }

  Future<void> addItem(String menuItemId, int quantity) async {
    try {
      final updated = await _service.addItem(menuItemId, quantity);
      await _setCart(updated);
    } on CartConflictException catch (e) {
      await _showConflict(e);
      rethrow;
    }
  }

  Future<void> updateQuantity(String menuItemId, int quantity) async {
    final updated = await _service.updateQuantity(menuItemId, quantity);
    await _setCart(updated);
  }

  Future<void> clear() async {
    final updated = await _service.clear();
    await _setCart(updated);
  }

  Future<CartValidationResult> validate() {
    return _service.validate();
  }

  Future<void> refreshCart() async {
    final updated = await _service.getCart();
    await _setCart(updated);
  }

  Future<void> _setCart(CartState cart) async {
    state = AsyncData(cart);
    await LocalStorage.cart.put('state', cart.toJson());
  }

  Future<void> _showConflict(CartConflictException e) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CartConflictDialog(
        existingRestaurant: e.existingRestaurant,
        newRestaurant: e.newRestaurant,
        onReplace: () async {
          await clear();
          await addItem(e.menuItemId, e.quantity);
        },
      ),
    );
  }
}
