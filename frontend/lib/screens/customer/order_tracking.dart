import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../providers/orders_provider.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/bitex_map.dart';

class OrderTracking extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTracking({super.key, required this.orderId});

  @override
  ConsumerState<OrderTracking> createState() => _OrderTrackingState();
}

class _OrderTrackingState extends ConsumerState<OrderTracking> {
  bool _ratingShown = false;
  bool _deliveredCelebrated = false;
  static const _fallbackRestaurantPin = LatLng(12.4219, 76.0200);
  static const _fallbackCustomerPin = LatLng(12.4240, 76.0230);

  @override
  void initState() {
    super.initState();
    unawaited(_loadActiveOrder());
  }

  Future<void> _loadActiveOrder() async {
    try {
      final order = await OrderService().getOrder(widget.orderId);
      if (order != null) {
        ref.read(activeOrderProvider.notifier).setActive(order);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        ref.read(activeOrderProvider.notifier).setActive(null);
      }
    }
  }

  Future<bool> _confirmBack(OrderModel? order) async {
    final active = order != null &&
        order.status != 'delivered' &&
        order.status != 'cancelled';
    if (!active) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Order in progress'),
        content: const Text('Order in progress. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    return result == true;
  }

  void _maybeShowRating(OrderModel order) {
    if (_ratingShown || order.status != 'delivered') return;
    _ratingShown = true;
    _deliveredCelebrated = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => _RatingSheet(orderId: order.id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final order = ref.watch(activeOrderProvider);
    if (order != null) _maybeShowRating(order);
    final restaurantPin = LatLng(
      order?.restaurantLatitude ?? _fallbackRestaurantPin.latitude,
      order?.restaurantLongitude ?? _fallbackRestaurantPin.longitude,
    );
    final customerPin = LatLng(
      order?.customerLatitude ?? _fallbackCustomerPin.latitude,
      order?.customerLongitude ?? _fallbackCustomerPin.longitude,
    );
    final partnerPin = LatLng(
      order?.partnerLatitude ?? restaurantPin.latitude,
      order?.partnerLongitude ?? restaurantPin.longitude,
    );
    final deliveryStage = order == null
        ? ''
        : (order.raw['delivery_stage'] ?? '').toString().toUpperCase();

    return WillPopScope(
      onWillPop: () => _confirmBack(order),
      child: Scaffold(
        appBar: AppBar(title: Text('Track Order', style: TextStyle(fontSize: R.sp(5.0)))),
        body: order == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 280,
                      child: BitexMap(
                        center: partnerPin,
                        showMyLocation: false,
                        polylinePoints: [restaurantPin, partnerPin, customerPin],
                        markers: [
                          MapMarker(
                            id: 'restaurant',
                            position: restaurantPin,
                            type: MapMarkerType.restaurant,
                            label: order.restaurantName.isEmpty ? 'Restaurant' : order.restaurantName,
                          ),
                          MapMarker(
                            id: 'customer',
                            position: customerPin,
                            type: MapMarkerType.customer,
                            label: 'Delivery',
                          ),
                          MapMarker(
                            id: 'partner',
                            position: partnerPin,
                            type: MapMarkerType.deliveryPartner,
                            label: 'Partner',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: R.hp(2.5)),
                    _buildTimeline(order.status),
                    SizedBox(height: R.hp(2.0)),
                    if (order.status == 'delivered')
                      _buildDeliveredCard(order)
                    else
                      _buildOtpCard(order.deliveryOtp),
                    if (deliveryStage == 'REACHED_CUSTOMER') ...[
                      SizedBox(height: R.hp(1.5)),
                      _buildReachedCard(),
                    ],
                    if (order.status == 'delivering') ...[
                      SizedBox(height: R.hp(1.5)),
                      _buildPartnerCard(order),
                    ],
                    SizedBox(height: R.hp(1.5)),
                    _buildRestaurantCard(order),
                    SizedBox(height: R.hp(1.5)),
                    _buildPaymentCard(order),
                  ],
                ),
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 2,
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
      ),
    );
  }

  Widget _buildReachedCard() {
    return _infoShell(
      color: Colors.green.shade50,
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Delivery partner has reached. Share the OTP to complete delivery.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String status) {
    final statuses = ['received', 'confirmed', 'preparing', 'delivering', 'delivered'];
    final labels = ['Placed', 'Confirmed', 'Preparing', 'On Way', 'Delivered'];
    final normalized = status == 'pickup_ready' ? 'preparing' : status;
    final current = statuses.indexOf(normalized).clamp(0, statuses.length - 1).toInt();
    return Row(
      children: List.generate(statuses.length, (index) {
        final done = index < current;
        final active = index == current;
        return Expanded(
          child: _buildStatusStep(labels[index], done, isActive: active),
        );
      }),
    );
  }

  Widget _buildStatusStep(String title, bool isDone, {bool isActive = false}) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.green
                : isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade200,
          ),
          child: Icon(isDone ? Icons.check : Icons.circle,
              color: isDone || isActive ? Colors.white : Colors.grey, size: 15),
        ),
        const SizedBox(height: 6),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isDone || isActive ? FontWeight.bold : FontWeight.normal,
              color: isDone || isActive ? AppTheme.textColor : AppTheme.greyColor,
            )),
      ],
    );
  }

  Widget _buildOtpCard(String? otp) {
    final digits = (otp == null || otp.isEmpty ? '----' : otp).split('');
    return _infoShell(
      child: Column(
        children: [
          const Text('Your Delivery OTP', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: digits
                .map((digit) => Text(digit, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Text('Share this with partner when food arrives'),
        ],
      ),
    );
  }

  Widget _buildDeliveredCard(OrderModel order) {
    return _infoShell(
      color: Colors.green.shade50,
      child: Column(
        children: [
          AnimatedScale(
            scale: _deliveredCelebrated ? 1 : 0.75,
            duration: const Duration(milliseconds: 500),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 54),
          ),
          const SizedBox(height: 8),
          const Text('Order Delivered!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Rate your experience'),
          const SizedBox(height: 6),
          const Text('★ ★ ★ ★ ★', style: TextStyle(color: Colors.amber, fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(OrderModel order) {
    final phone = order.partnerPhone;
    final masked = phone.length > 4 ? '${phone.substring(0, phone.length - 4).replaceAll(RegExp(r'\d'), 'X')}${phone.substring(phone.length - 4)}' : phone;
    return _infoShell(
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.delivery_dining)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.partnerName.isEmpty ? 'Delivery partner' : order.partnerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${order.partnerVehicleNumber}  ${order.partnerRating.toStringAsFixed(1)} ★'),
                if (masked.isNotEmpty) Text(masked),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:$phone')),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(OrderModel order) {
    return _infoShell(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.restaurant),
        title: Text(order.restaurantName.isEmpty ? 'Restaurant' : order.restaurantName),
        subtitle: Text(order.restaurantAddress.isEmpty ? 'Preparing your order' : order.restaurantAddress),
        trailing: Text(order.estimatedMinutes > 0 ? '${order.estimatedMinutes} min' : 'ETA'),
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    final method = order.paymentMethod.toUpperCase();
    final status = method == 'COD' || method == 'CASH'
        ? 'Pay ₹${order.totalAmount.toStringAsFixed(0)} Cash'
        : 'Paid Online';
    return _infoShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment summary', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _summaryRow('Items total', order.itemsTotal == 0 ? order.totalAmount : order.itemsTotal),
          _summaryRow('Delivery fee', order.deliveryFee),
          const Divider(),
          _summaryRow('Total paid', order.totalPaid == 0 ? order.totalAmount : order.totalPaid, bold: true),
          const SizedBox(height: 6),
          Text(status, style: TextStyle(color: method == 'COD' || method == 'CASH' ? Colors.brown : Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _infoShell({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final String orderId;
  const _RatingSheet({required this.orderId});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 5;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await apiClient.client.post('/reviews', data: {
      'order_id': widget.orderId,
      'food_rating': _rating,
      'delivery_rating': _rating,
      'comment': '',
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rate your order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < _rating ? Icons.star : Icons.star_border),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
