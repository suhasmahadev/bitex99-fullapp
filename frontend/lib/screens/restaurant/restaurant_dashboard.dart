import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../providers/user_provider.dart';
import '../../services/restaurant_service.dart';
import '../../services/order_service.dart';
import '../../services/ws_service.dart';
import '../../models/models.dart';
import '../../widgets/order_notification_banner.dart';
import '../onboarding/login_screen.dart';
import '../../core/token_storage.dart';


class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _IncomingOrderCard extends StatefulWidget {
  final OrderModel order;
  final int selectedPrepTime;
  final ValueChanged<int> onPrepSelected;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingOrderCard({
    required this.order,
    required this.selectedPrepTime,
    required this.onPrepSelected,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_IncomingOrderCard> createState() => _IncomingOrderCardState();
}

class _IncomingOrderCardState extends State<_IncomingOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.orderItems.isEmpty
        ? widget.order.items.map((i) => '${i['name']} x${i['quantity']}').join('\n')
        : widget.order.orderItems.map((i) => '${i.name} x${i.quantity}        ₹${i.totalPrice.toStringAsFixed(0)}').join('\n');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEW ORDER  #${widget.order.id.length > 6 ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase() : widget.order.id}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(items),
            const Divider(height: 22),
            Text('Total ₹${widget.order.totalAmount.toStringAsFixed(0)}  •  ${widget.order.paymentMethod.toUpperCase()}  •  500m'),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final left = (90 - (_controller.value * 90)).ceil();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-reject in ${left}s'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: 1 - _controller.value),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [15, 20, 25, 30].map((time) {
                return ChoiceChip(
                  label: Text('$time min'),
                  selected: widget.selectedPrepTime == time,
                  onSelected: (_) => widget.onPrepSelected(time),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  List<OrderModel> _orders = [];
  final List<OrderModel> _incomingOrders = [];
  RestaurantModel? _restaurant;
  bool _isLoading = true;
  int _selectedPrepTime = 20;

  static bool _wsStarted = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    if (!_wsStarted) {
      _wsStarted = true;
      _initWs();
    }
  }

  Future<void> _initWs() async {
    final role = await TokenStorage.getRole();
    debugPrint('RestaurantDashboard: initWs role=$role');
    if (role != 'RESTAURANT_PARTNER' && role != 'restaurant') {
      debugPrint('RestaurantDashboard: skipping WS \u2014 wrong role $role');
      return;
    }
    WsService.instance.connectRestaurantOrders();
    _wsSub = WsService.instance.restaurantOrderStream.listen(_handleWsEvent);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    WsService.instance.disconnectRestaurantOrders();
    super.dispose();
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? event['event'] ?? '').toString();
    if (event['orders'] is List) {
      final orders = (event['orders'] as List)
          .whereType<Map>()
          .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
          .where((order) => order.id.isNotEmpty)
          .toList();
      if (orders.isEmpty || !mounted) return;
      setState(() {
        for (final order in orders) {
          _orders.removeWhere((item) => item.id == order.id);
          _orders.insert(0, order);
          if (order.status == 'received') {
            _incomingOrders.removeWhere((item) => item.id == order.id);
            _incomingOrders.insert(0, order);
          }
        }
      });
      return;
    }
    final data = event['order'] ?? event['data'] ?? event;
    if (data is! Map) return;
    final order = OrderModel.fromJson(Map<String, dynamic>.from(data));
    if (order.id.isEmpty) return;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _orders.removeWhere((item) => item.id == order.id);
      _orders.insert(0, order);
      if (type == 'NEW_ORDER' || order.status == 'received') {
        _incomingOrders.removeWhere((item) => item.id == order.id);
        _incomingOrders.insert(0, order);
      }
    });
    if (type == 'NEW_ORDER') {
      OrderNotificationBanner.show(
        context,
        message: 'New order from ${order.customerId.isEmpty ? 'customer' : order.customerId}!',
      );
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final userProv = Provider.of<UserProvider>(context, listen: false);
      final restaurantId = userProv.phone; // Using phone as ID per original code

      final orders = await OrderService().getOrdersForRestaurant(restaurantId);
      final restaurant = await RestaurantService().getRestaurantById(restaurantId);
      
      if (mounted) {
        setState(() {
          _orders = orders;
          _restaurant = restaurant;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    if (orderId.isEmpty) {
      debugPrint('ERROR: orderId is empty, cannot update to $status');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Order ID is missing')),
        );
      }
      return;
    }
    debugPrint('Updating order $orderId to status $status');
    try {
      if (status == 'confirmed') {
        await OrderService().acceptRestaurantOrder(orderId, preparationTime: _selectedPrepTime);
      } else if (status == 'cancelled') {
        await OrderService().rejectRestaurantOrder(orderId);
      } else if (status == 'preparing') {
        await OrderService().markRestaurantPreparing(orderId);
      } else if (status == 'pickup_ready') {
        await OrderService().markRestaurantReady(orderId);
      }
      _incomingOrders.removeWhere((order) => order.id == orderId);
      _loadDashboard(); // Refresh
    } catch (e) {
      debugPrint('Order update failed for $orderId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final userProv = Provider.of<UserProvider>(context);
    final restaurantId = userProv.phone;
    
    final isOpen = _restaurant?.isOpen ?? false;

    if (_isLoading && _orders.isEmpty && _restaurant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculate stats
    final today = DateTime.now();
    final todayOrders = _orders.where((o) => o.createdAt.day == today.day && o.createdAt.month == today.month && o.createdAt.year == today.year).toList();
    final revenue = todayOrders.where((o) => o.status == 'delivered').fold(0.0, (sum, o) => sum + o.totalAmount);
    
    // Filter active orders
    final activeOrders = _orders.where((o) => o.status != 'delivered' && o.status != 'cancelled' && o.status != 'received').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          backgroundColor: Colors.black,
          title: Image.asset(
            'assets/images/bitex99_logo.png',
            height: 24,
            fit: BoxFit.contain,
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: R.wp(2.0)),
              child: Row(
                children: [
                  Container(
                    width: R.wp(2.0),
                    height: R.wp(2.0),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: R.wp(2.0)),
                  Text(
                    isOpen ? 'Online' : 'Offline',
                    style: TextStyle(fontSize: R.sp(3.5), color: isOpen ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: isOpen,
                    onChanged: (val) async {
                      try {
                        await RestaurantService().toggleOnlineStatus(restaurantId, val);
                        _loadDashboard();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.withOpacity(0.3),
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.logout, size: R.wp(6.0), color: Colors.red),
              onPressed: () {
                userProv.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen(town: '')),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(child: _buildStatCard(context, 'Today\'s Orders', '${todayOrders.length}', Colors.blue, Icons.receipt_long)),
                SizedBox(width: R.wp(4.0)),
                Expanded(child: _buildStatCard(context, 'Revenue', '₹ ${revenue.toStringAsFixed(0)}', Colors.green, Icons.currency_rupee)),
              ],
            ),
            SizedBox(height: R.hp(2.5)),
            if (_incomingOrders.isNotEmpty) ...[
              Text('Incoming orders', style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w700)),
              SizedBox(height: R.hp(1.5)),
              ..._incomingOrders.map((order) => _IncomingOrderCard(
                    order: order,
                    selectedPrepTime: _selectedPrepTime,
                    onPrepSelected: (value) => setState(() => _selectedPrepTime = value),
                    onAccept: () => _updateOrderStatus(order.id, 'confirmed'),
                    onReject: () => _updateOrderStatus(order.id, 'cancelled'),
                  )),
              SizedBox(height: R.hp(2.0)),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Orders',
                  style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.w600),
                ),
                Text(
              '${activeOrders.length} Active',
                  style: TextStyle(fontSize: R.sp(3.5), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: R.hp(1.5)),
            if (activeOrders.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: R.hp(10.0)),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: R.wp(15.0), color: Colors.grey.shade300),
                      SizedBox(height: R.hp(2.0)),
                      Text('No active orders', style: TextStyle(fontSize: R.sp(4.5), color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              _buildKanban(activeOrders),
            SizedBox(height: R.hp(2.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildKanban(List<OrderModel> orders) {
    final columns = {
      'confirmed': 'CONFIRMED',
      'preparing': 'PREPARING',
      'pickup_ready': 'READY',
    };
    return Column(
      children: columns.entries.map((entry) {
        final list = orders.where((order) => order.status == entry.key).toList();
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: R.hp(2.0)),
          padding: EdgeInsets.all(R.wp(3.0)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.value} (${list.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: R.hp(1.0)),
              if (list.isEmpty)
                Text('No orders', style: TextStyle(color: Colors.grey.shade500))
              else
                ...list.map((order) => _buildOrderCard(context, order)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color, IconData icon) {
    return Container(
      height: R.hp(13.0),
      padding: EdgeInsets.all(R.wp(4.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: R.wp(6.5)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: R.sp(6.0),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    Color statusColor = order.status == 'received'
        ? Colors.blue
        : order.status == 'preparing'
            ? Colors.orange
            : Colors.green;

    String itemsText = order.items.map((i) => '${i['name']} × ${i['quantity']}').join(', ');

    return Container(
      margin: EdgeInsets.only(bottom: R.hp(2.0)),
      padding: EdgeInsets.all(R.hp(2.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER #${order.id.length > 4 ? order.id.substring(order.id.length - 4).toUpperCase() : order.id}',
                style: TextStyle(fontSize: R.sp(4.0), fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: R.wp(2.0), vertical: R.hp(0.3)),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(fontSize: R.sp(3.0), color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: R.hp(1.0)),
          Text(
            itemsText,
            style: TextStyle(fontSize: R.sp(3.8), color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: R.hp(0.8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount: ₹ ${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: R.sp(4.0), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              Text(
                order.paymentMethod,
                style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: R.hp(1.5)),
          if (order.status == 'confirmed')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateOrderStatus(order.id, 'preparing'),
                child: const Text('Start Preparing'),
              ),
            )
          else if (order.status == 'received')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateOrderStatus(order.id, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(2.0))),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                SizedBox(width: R.wp(4.0)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus(order.id, 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(2.0))),
                    ),
                    child: const Text('Accept', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          else if (order.status == 'preparing')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateOrderStatus(order.id, 'pickup_ready'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(2.0))),
                ),
                child: const Text('Mark as Ready', style: TextStyle(color: Colors.white)),
              ),
            )
          else if (order.status == 'pickup_ready')
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(R.wp(3.0)),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(R.wp(2.0)),
              ),
              child: Column(
                children: [
                  Text(
                    'WAITING FOR PICKUP',
                    style: TextStyle(fontSize: R.sp(3.5), fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  SizedBox(height: R.hp(0.5)),
                  Text(
                    'Pickup Code: ${order.pickupCode}',
                    style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
