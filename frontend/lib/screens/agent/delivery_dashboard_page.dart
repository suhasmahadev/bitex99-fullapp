import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/token_storage.dart';
import '../../utils/responsive.dart';
import '../onboarding/login_screen.dart';
import 'widgets/order_card.dart';
import 'widgets/active_order_widget.dart';
import 'agent_profile_screen.dart';
import 'delivery_kyc_page.dart';
import 'kyc_pending_page.dart';
import 'kyc_rejected_page.dart';

const _navy = Color(0xFF1A1A2E);
const _orange = Color(0xFFE8593C);

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({super.key});

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>();
      final agentId = user.uid.isNotEmpty ? user.uid : user.phone;
      context.read<DeliveryProvider>().initForUser(agentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DeliveryProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goToLogin();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: switch (prov.kycStatus) {
          KYCStatus.notSubmitted => const DeliveryKYCPage(),
          KYCStatus.pending => const KYCPendingPage(),
          KYCStatus.rejected => const KYCRejectedPage(),
          KYCStatus.approved => const _DashboardView(),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  int _tabIndex = 0; // 0=Orders, 1=Active, 2=Earnings, 3=Notifications

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final prov = context.watch<DeliveryProvider>();
    final user = context.read<UserProvider>();

    // Auto-switch to Active tab when order accepted
    if (prov.hasActiveOrder && _tabIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = 1);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // ── TOP HEADER ────────────────────────────────
          _Header(
              agentName: prov.agentName.isEmpty ? 'Delivery Partner' : prov.agentName),
          // ── STATS ROW ─────────────────────────────────
          _StatsRow(prov: prov),
          // ── ONLINE TOGGLE ────────────────────────────
          _OnlineToggle(prov: prov),
          _SurgeStatusCard(prov: prov),
          // ── TAB BAR ──────────────────────────────────
          _TabBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            orderCount: prov.availableOrders.length,
            notifCount: prov.notifications.length,
            hasActive: prov.hasActiveOrder,
          ),
          // ── CONTENT ──────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: switch (_tabIndex) {
                0 => _OrdersTab(prov: prov, key: const ValueKey(0)),
                1 => _ActiveTab(prov: prov, key: const ValueKey(1)),
                2 => _EarningsTab(prov: prov, key: const ValueKey(2)),
                _ => const AgentProfileScreen(key: ValueKey(3)),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String agentName;
  const _Header({required this.agentName});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: R.hp(5.5), left: R.wp(5.0), right: R.wp(5.0), bottom: R.hp(2.5)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [_navy, Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BiteX99 logo ──────────────────────────────────────
          Row(
            children: [
              Image.asset(
                'assets/images/bitex99_logo.png',
                height: R.hp(3.0),
                fit: BoxFit.contain,
              ),
              const Spacer(),
              // Notification bell
              Stack(
                children: [
                  Icon(Icons.notifications_outlined,
                      color: Colors.white70, size: R.wp(7.0)),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: R.wp(3.5),
                      height: R.wp(3.5),
                      decoration: const BoxDecoration(
                          color: _orange, shape: BoxShape.circle),
                      child: Center(
                          child: Text('3',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: R.sp(2.0),
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: R.hp(1.8)),
          // ── Agent info row ─────────────────────────────────────
          Row(
            children: [
              Container(
                width: R.wp(13.0),
                height: R.wp(13.0),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2), shape: BoxShape.circle),
                child:
                    Icon(Icons.delivery_dining, color: Theme.of(context).colorScheme.primary, size: R.wp(8.0)),
              ),
              SizedBox(width: R.wp(3.5)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style:
                          TextStyle(color: Colors.white60, fontSize: R.sp(3.5)),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agentName,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: R.sp(5.5),
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: R.wp(2.0)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: R.wp(1.5), vertical: 2),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('KYC ✓',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: R.sp(2.5),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final DeliveryProvider prov;
  const _StatsRow({required this.prov});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: R.hp(1.8)),
      child: Row(
        children: [
          _statItem('${prov.todayDeliveries}', "Today's Orders",
              Icons.receipt_long, Colors.blue),
          Container(width: 1, height: R.hp(5.0), color: Colors.grey.shade200),
          _statItem('₹ ${prov.todayEarnings.toStringAsFixed(0)}',
              "Today's Earning", Icons.currency_rupee, Theme.of(context).colorScheme.primary),
          Container(width: 1, height: R.hp(5.0), color: Colors.grey.shade200),
          _statItem('4.9 ★', 'Rating', Icons.star, Colors.amber),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: R.wp(5.5)),
          SizedBox(height: R.hp(0.4)),
          Text(value,
              style: TextStyle(
                  fontSize: R.sp(4.2),
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style:
                  TextStyle(fontSize: R.sp(2.8), color: Colors.grey.shade500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONLINE TOGGLE BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _OnlineToggle extends StatelessWidget {
  final DeliveryProvider prov;
  const _OnlineToggle({required this.prov});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: prov.isOnline ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.grey.shade200,
      padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(1.5)),
      child: Row(
        children: [
          // Pulsing dot
          _PulsingDot(isOnline: prov.isOnline),
          SizedBox(width: R.wp(2.5)),
          Text(
            prov.isOnline
                ? 'You are in ${prov.currentCity}'
                : 'You are Offline — not receiving orders',
            style: TextStyle(
              fontSize: R.sp(3.8),
              fontWeight: FontWeight.w600,
              color: prov.isOnline ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          // Toggle switch
          GestureDetector(
            onTap: () => prov.toggleOnline(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: R.wp(14.0),
              height: R.hp(3.5),
              decoration: BoxDecoration(
                color: prov.isOnline ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    alignment: prov.isOnline
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: R.hp(2.8),
                        height: R.hp(2.8),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool isOnline;
  const _PulsingDot({required this.isOnline});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    if (!widget.isOnline) {
      return Container(
          width: R.wp(3.5),
          height: R.wp(3.5),
          decoration: BoxDecoration(
              color: Colors.grey.shade400, shape: BoxShape.circle));
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: R.wp(3.5),
        height: R.wp(3.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(_anim.value),
          boxShadow: [
            BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5 * _anim.value),
                blurRadius: 6,
                spreadRadius: 2)
          ],
        ),
      ),
    );
  }
}

class _SurgeStatusCard extends StatelessWidget {
  final DeliveryProvider prov;
  const _SurgeStatusCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    final status = prov.surgeStatus;
    if (status == null) return const SizedBox.shrink();
    final surgeActive = status['surge_active'] == true || status['is_active'] == true;
    final rainActive = status['rain_active'] == true;
    if (!surgeActive && !rainActive) return const SizedBox.shrink();
    final amount = status['amount'] ?? status['bonus_amount'] ?? 20;
    final area = status['area'] ?? status['city'] ?? prov.currentCity;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surgeActive ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surgeActive ? Colors.orange : Colors.blue, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(surgeActive ? Icons.bolt : Icons.water_drop, color: surgeActive ? Colors.orange : Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              surgeActive
                  ? 'Surge Active  +₹$amount per delivery  $area'
                  : 'Rain Bonus Active  +₹$amount extra per delivery',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRequestOverlay extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _DeliveryRequestOverlay({
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_DeliveryRequestOverlay> createState() => _DeliveryRequestOverlayState();
}

class _DeliveryRequestOverlayState extends State<_DeliveryRequestOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 45))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payout = (widget.order.totalAmount * 0.22).clamp(38, 120).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _orange, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('New Delivery Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          const SizedBox(height: 14),
          Text(widget.order.restaurantName.isEmpty ? 'Restaurant' : widget.order.restaurantName, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.order.restaurantAddress.isEmpty ? 'Pickup address' : widget.order.restaurantAddress),
          const SizedBox(height: 10),
          Text('Drop: ${widget.order.landmark.isEmpty ? 'Customer address' : widget.order.landmark}'),
          const SizedBox(height: 10),
          Text('Estimated: ₹$payout', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Text('Base ₹20 + Distance ₹9 + Peak ₹8'),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final left = (45 - _controller.value * 45).ceil();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${left}s'),
                  LinearProgressIndicator(value: 1 - _controller.value),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: widget.onReject, child: const Text('Reject'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: widget.onAccept, child: const Text('Accept'))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int orderCount;
  final int notifCount;
  final bool hasActive;

  const _TabBar({
    required this.currentIndex,
    required this.onTap,
    required this.orderCount,
    required this.notifCount,
    required this.hasActive,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final tabs = [
      ('Available', Icons.list_alt, orderCount),
      ('Active', Icons.navigation, hasActive ? 1 : 0),
      ('Earnings', Icons.currency_rupee, 0),
      ('Profile', Icons.person_outline, 0),
    ];

    return Container(
      color: Colors.white,
      child: Row(
        children: tabs.indexed.map(((int, (String, IconData, int)) entry) {
          final (i, (label, icon, badge)) = entry;
          final active = currentIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: R.hp(1.5)),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: 2.5)),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon,
                            color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                            size: R.wp(6.0)),
                        if (badge > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              width: R.wp(4.5),
                              height: R.wp(4.5),
                              decoration: BoxDecoration(
                                  color: i == 1 ? Theme.of(context).colorScheme.primary : _orange,
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text('$badge',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: R.sp(2.2),
                                          fontWeight: FontWeight.bold))),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: R.hp(0.4)),
                    Text(label,
                        style: TextStyle(
                            fontSize: R.sp(3.0),
                            color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — AVAILABLE ORDERS
// ─────────────────────────────────────────────────────────────────────────────
class _OrdersTab extends StatelessWidget {
  final DeliveryProvider prov;
  const _OrdersTab({required this.prov, super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);

    if (!prov.isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: R.wp(18.0), color: Colors.grey.shade300),
            SizedBox(height: R.hp(2.5)),
            Text('You are Offline',
                style: TextStyle(
                    fontSize: R.sp(5.5),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500)),
            SizedBox(height: R.hp(1.0)),
            Text('Toggle Online to see orders',
                style: TextStyle(
                    fontSize: R.sp(4.0), color: Colors.grey.shade400)),
            SizedBox(height: R.hp(3.5)),
            ElevatedButton.icon(
              onPressed: () => prov.toggleOnline(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(R.wp(55.0), R.hp(7.0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(R.wp(3.0))),
              ),
              icon: const Icon(Icons.power_settings_new),
              label: Text('Go Online',
                  style: TextStyle(
                      fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (prov.hasActiveOrder) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation, size: R.wp(15.0), color: Theme.of(context).colorScheme.primary),
            SizedBox(height: R.hp(2.0)),
            Text('Active delivery in progress',
                style: TextStyle(
                    fontSize: R.sp(4.5),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            SizedBox(height: R.hp(1.0)),
            Text('Switch to Active tab',
                style: TextStyle(
                    fontSize: R.sp(3.8), color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    if (prov.availableOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: R.wp(18.0), color: Colors.grey.shade300),
            SizedBox(height: R.hp(2.5)),
            Text('No orders available',
                style: TextStyle(
                    fontSize: R.sp(5.0), color: Colors.grey.shade500)),
            SizedBox(height: R.hp(1.0)),
            Text('Check back in a moment',
                style: TextStyle(
                    fontSize: R.sp(3.8), color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(2.0)),
      children: [
        if (prov.latestRequest != null && prov.availableOrders.isNotEmpty)
          _DeliveryRequestOverlay(
            order: prov.availableOrders.first,
            onAccept: () => prov.acceptOrder(prov.availableOrders.first),
            onReject: () => prov.rejectOrder(prov.availableOrders.first),
          ),
        // Swipe hint
        Container(
          margin: EdgeInsets.only(bottom: R.hp(1.5)),
          padding:
              EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.0)),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(R.wp(2.5)),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.swap_horiz,
                  color: Colors.blue.shade600, size: R.wp(5.0)),
              SizedBox(width: R.wp(2.5)),
              Expanded(
                child: Text(
                  'Swipe right to accept • Swipe left to reject',
                  style: TextStyle(
                      fontSize: R.sp(3.5), color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        ...prov.availableOrders.map((order) => OrderCard(
              key: ValueKey(order.id),
              order: order,
              onAccept: () {
                prov.acceptOrder(order);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Order ${order.id} accepted! Head to restaurant ${order.restaurantId}'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(R.wp(3.0))),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              onReject: () {
                prov.rejectOrder(order);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order ${order.id} rejected'),
                    backgroundColor: Colors.grey.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(R.wp(3.0))),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — ACTIVE DELIVERY
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  final DeliveryProvider prov;
  const _ActiveTab({required this.prov, super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    if (!prov.hasActiveOrder) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: R.wp(18.0), color: Colors.grey.shade300),
            SizedBox(height: R.hp(2.5)),
            Text('No active delivery',
                style: TextStyle(
                    fontSize: R.sp(5.0), color: Colors.grey.shade500)),
            SizedBox(height: R.hp(1.0)),
            Text('Accept an order to start delivering',
                style: TextStyle(
                    fontSize: R.sp(3.8), color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return const SingleChildScrollView(child: ActiveOrderWidget());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — EARNINGS
// ─────────────────────────────────────────────────────────────────────────────
class _EarningsTab extends StatelessWidget {
  final DeliveryProvider prov;
  const _EarningsTab({required this.prov, super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    const maxAmt = 510.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.5), vertical: R.hp(2.5)),
      child: Column(
        children: [
          // ── Today summary card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(R.wp(5.0)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary, const Color(0xFF00CC66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(R.wp(4.0)),
            ),
            child: Column(
              children: [
                Text("Today's Earnings",
                    style:
                        TextStyle(color: Colors.white70, fontSize: R.sp(3.8))),
                SizedBox(height: R.hp(1.0)),
                Text(
                  '₹ ${prov.todayEarnings.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: R.sp(10.0),
                      fontWeight: FontWeight.w900),
                ),
                SizedBox(height: R.hp(2.0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryChip('Deliveries', '${prov.todayDeliveries}'),
                    Container(
                        width: 1, height: R.hp(4.0), color: Colors.white30),
                    _summaryChip('Avg/Order',
                        '₹ ${(prov.todayEarnings / prov.todayDeliveries).toStringAsFixed(0)}'),
                    Container(
                        width: 1, height: R.hp(4.0), color: Colors.white30),
                    _summaryChip(
                        'Weekly', '₹ ${prov.weeklyTotal.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: R.hp(2.5)),
          // ── Weekly bar chart
          const _SectionHeader('Weekly Overview'),
          SizedBox(height: R.hp(1.5)),
          Container(
            height: R.hp(26.0),
            padding: EdgeInsets.symmetric(
                horizontal: R.wp(2.0), vertical: R.hp(2.0)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(R.wp(3.5)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: prov.weeklyData.map((r) {
                final ratio = r.amount / maxAmt;
                final isToday = r.day == 'Sun';
                return _WeekBar(record: r, ratio: ratio, isToday: isToday);
              }).toList(),
            ),
          ),
          SizedBox(height: R.hp(2.5)),
          // ── Daily history
          const _SectionHeader('Daily History'),
          SizedBox(height: R.hp(1.5)),
          ...prov.weeklyData.reversed.map((r) => _HistoryRow(record: r)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: R.sp(3.0))),
        SizedBox(height: R.hp(0.4)),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: R.sp(4.5),
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  final EarningsRecord record;
  final double ratio;
  final bool isToday;

  const _WeekBar(
      {required this.record, required this.ratio, required this.isToday});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final barH = (R.hp(26.0) - R.hp(6.0)) * ratio;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '₹${record.amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: R.sp(2.6),
              color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
        ),
        SizedBox(height: R.hp(0.5)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: R.wp(9.0),
          height: barH.clamp(R.hp(1.0), R.hp(20.0)),
          decoration: BoxDecoration(
            color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(R.wp(2.0)),
          ),
        ),
        SizedBox(height: R.hp(0.8)),
        Text(record.day,
            style: TextStyle(
                fontSize: R.sp(3.2),
                color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final EarningsRecord record;
  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      margin: EdgeInsets.only(bottom: R.hp(1.5)),
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.5), vertical: R.hp(1.8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: R.wp(11.0),
            height: R.wp(11.0),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(
                child: Text(record.day,
                    style: TextStyle(
                        fontSize: R.sp(3.5),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary))),
          ),
          SizedBox(width: R.wp(3.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record.deliveries} deliveries',
                    style: TextStyle(
                        fontSize: R.sp(4.0), fontWeight: FontWeight.w600)),
                Text(
                    '₹ ${(record.amount / record.deliveries).toStringAsFixed(0)}/order avg',
                    style: TextStyle(
                        fontSize: R.sp(3.2), color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text('₹ ${record.amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: R.sp(5.0),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — NOTIFICATIONS / LOG
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsTab extends StatelessWidget {
  final DeliveryProvider prov;
  const _NotificationsTab({required this.prov});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    if (prov.notifications.isEmpty) {
      return Center(
          child: Text('No recent activity',
              style:
                  TextStyle(fontSize: R.sp(4.5), color: Colors.grey.shade400)));
    }
    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.5)),
          child: Row(
            children: [
              Text('Recent Activity',
                  style: TextStyle(
                      fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => prov.clearNotifications(),
                child: Text('Clear all',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: R.sp(3.5))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: R.wp(4.0)),
            itemCount: prov.notifications.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) {
              final msg = prov.notifications[i];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: R.wp(2.0), vertical: R.hp(0.5)),
                leading: Container(
                  width: R.wp(10.0),
                  height: R.wp(10.0),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child:
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: R.wp(5.5)),
                ),
                title: Text(msg, style: TextStyle(fontSize: R.sp(3.8))),
                subtitle: Text('Just now',
                    style: TextStyle(
                        fontSize: R.sp(3.0), color: Colors.grey.shade500)),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title,
          style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.bold)),
    );
  }
}
