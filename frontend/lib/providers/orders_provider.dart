import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../models/models.dart';
import '../services/order_service.dart';
import '../services/ws_service.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

final ordersProvider =
    AsyncNotifierProvider<OrdersController, List<OrderModel>>(
  OrdersController.new,
);

final activeOrderProvider =
    StateNotifierProvider<ActiveOrderController, OrderModel?>(
  (ref) => ActiveOrderController(ref),
);

class OrdersController extends AsyncNotifier<List<OrderModel>> {
  final _service = OrderService();

  @override
  Future<List<OrderModel>> build() async {
    ref.watch(authProvider);
    final cached = LocalStorage.orders.get('history');
    if (cached is List) {
      state = AsyncData(cached
          .whereType<Map>()
          .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
          .toList());
    }
    if (ref.read(authProvider).valueOrNull == null) {
      return state.valueOrNull ?? [];
    }
    return refreshOrders();
  }

  Future<OrderModel> placeOrder({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final validation = await ref.read(cartProvider.notifier).validate();
    if (!validation.isValid || !validation.restaurantIsOpen) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(validation.restaurantIsOpen
                ? 'Unavailable items'
                : 'Restaurant is closed'),
            content: Text(validation.restaurantIsOpen
                ? validation.invalidItems.join('\n')
                : 'Restaurant is closed'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      throw Exception('Cart validation failed');
    }

    try {
      final order = await _service.placeOrder(
        addressId: addressId,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );
      await refreshOrders();
      await ref.read(cartProvider.notifier).refreshCart();
      ref.read(activeOrderProvider.notifier).setActive(order);
      rootNavigatorKey.currentContext?.go('/order/${order.id}/tracking');
      return order;
    } catch (e) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      rethrow;
    }
  }

  Future<OrderModel> cancelOrder(String id, String reason) async {
    final order = await _service.cancelOrder(id, reason);
    await refreshOrders();
    return order;
  }

  Future<List<OrderModel>> refreshOrders() async {
    final orders = await _service.getOrders();
    await LocalStorage.orders.put(
      'history',
      orders.map((order) => order.toMap()..['id'] = order.id).toList(),
    );
    state = AsyncData(orders);
    final active = orders.where((order) =>
        order.status != 'delivered' && order.status != 'cancelled').toList();
    if (active.isNotEmpty) {
      ref.read(activeOrderProvider.notifier).setActive(active.first);
    }
    return orders;
  }
}

class ActiveOrderController extends StateNotifier<OrderModel?> {
  final Ref _ref;
  StreamSubscription<OrderModel>? _wsSub;
  final _service = OrderService();

  ActiveOrderController(this._ref) : super(null) {
    _ref.onDispose(() {
      _wsSub?.cancel();
      WsService.instance.disconnectCustomerOrder();
    });
    _ref.listen(authProvider, (_, next) {
      if (next.valueOrNull == null) {
        _stopLive(clearOrder: true);
      }
    });
  }

  void setActive(OrderModel? order) {
    state = order;
    _stopLive();
    if (order == null ||
        order.status == 'delivered' ||
        order.status == 'cancelled') {
      return;
    }
    unawaited(WsService.instance.connectCustomerOrder(order.id));
    _wsSub = WsService.instance.customerOrderStream.listen((updated) {
      if (updated.id != order.id) return;
      state = updated;
      if (updated.status == 'delivered' || updated.status == 'cancelled') {
        _stopLive();
      }
    });
  }

  void _stopLive({bool clearOrder = false}) {
    _wsSub?.cancel();
    _wsSub = null;
    WsService.instance.disconnectCustomerOrder();
    if (clearOrder) state = null;
  }
}
