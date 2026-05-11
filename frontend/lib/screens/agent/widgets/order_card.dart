import 'package:flutter/material.dart';
import '../../../providers/delivery_provider.dart';
import '../../../models/models.dart';
import '../../../utils/responsive.dart';

const _red = Color(0xFFE23744);

/// Swipeable order card — swipe right to accept, swipe left to reject.
class OrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> with SingleTickerProviderStateMixin {
  double _dragX = 0;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _bounceAnim = Tween<double>(begin: 0, end: 0).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissed) return;
    setState(() => _dragX += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissed) return;
    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (_dragX > threshold) {
      _dismissed = true;
      widget.onAccept();
    } else if (_dragX < -threshold) {
      _dismissed = true;
      widget.onReject();
    } else {
      // Snap back
      setState(() => _dragX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final swipeRatio = (_dragX / (MediaQuery.of(context).size.width * 0.5)).clamp(-1.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(bottom: R.hp(2.0)),
        transform: Matrix4.translationValues(_dragX, 0, 0)..rotateZ(swipeRatio * 0.05),
        child: Stack(
          children: [
            // Accept hint (right)
            if (_dragX > 20)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(R.wp(4.0)),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.only(left: R.wp(6.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: R.wp(10.0)),
                      Text('ACCEPT', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: R.sp(3.5), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            // Reject hint (left)
            if (_dragX < -20)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(R.wp(4.0)),
                  ),
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: R.wp(6.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, color: _red, size: R.wp(10.0)),
                      Text('REJECT', style: TextStyle(color: _red, fontSize: R.sp(3.5), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            // Main card
            _buildCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    // R already init'd in build(), safe to use here
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(4.0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.wp(4.5), vertical: R.hp(1.5)),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(R.wp(4.0)),
                topRight: Radius.circular(R.wp(4.0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: R.wp(2.5), vertical: R.hp(0.5)),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.order.id, style: TextStyle(fontSize: R.sp(3.5), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(Icons.swap_horiz, color: Colors.grey.shade400, size: R.wp(4.5)),
                SizedBox(width: R.wp(1.0)),
                Text('Swipe to act', style: TextStyle(fontSize: R.sp(3.0), color: Colors.grey.shade400)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(R.wp(4.5)),
            child: Column(
              children: [
                // Pickup row
                _locationRow(
                  context: context,
                  icon: Icons.store_mall_directory_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  title: 'Restaurant ${widget.order.restaurantId.length > 4 ? widget.order.restaurantId.substring(0,4) : widget.order.restaurantId}',
                  subtitle: 'Pickup Address',
                  tag: 'PICKUP',
                ),
                // Route line
                Padding(
                  padding: EdgeInsets.only(left: R.wp(4.5)),
                  child: Row(
                    children: [
                      Container(width: 1.5, height: R.hp(3.0), color: Colors.grey.shade300),
                      SizedBox(width: R.wp(3.0)),
                      Text('1.5 km', style: TextStyle(fontSize: R.sp(3.2), color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                // Drop row
                _locationRow(
                  context: context,
                  icon: Icons.location_on_rounded,
                  color: _red,
                  title: 'Customer ${widget.order.customerId.length > 4 ? widget.order.customerId.substring(0,4) : widget.order.customerId}',
                  subtitle: widget.order.landmark.isNotEmpty ? widget.order.landmark : 'Drop Address',
                  tag: 'DELIVER',
                ),
                SizedBox(height: R.hp(1.5)),
                // Items
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: R.wp(3.0), vertical: R.hp(1.0)),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(R.wp(2.0))),
                  child: Text(
                    widget.order.orderItems.isEmpty 
                        ? 'No items' 
                        : widget.order.orderItems.map((e) => '${e.name} x${e.quantity}').join(', '),
                    style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: R.hp(2.0)),
                // Earnings + buttons
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Payout', style: TextStyle(fontSize: R.sp(3.0), color: Colors.grey.shade600)),
                        Text(
                          '₹ ${(widget.order.totalAmount * 0.1).clamp(20, 100).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: R.sp(6.0), fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Reject
                    GestureDetector(
                      onTap: widget.onReject,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.5)),
                        decoration: BoxDecoration(
                          border: Border.all(color: _red.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(R.wp(2.5)),
                          color: _red.withOpacity(0.06),
                        ),
                        child: Text('Reject', style: TextStyle(fontSize: R.sp(3.8), color: _red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(width: R.wp(2.5)),
                    // Accept
                    GestureDetector(
                      onTap: widget.onAccept,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(1.5)),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(R.wp(2.5)),
                        ),
                        child: Text('Accept', style: TextStyle(fontSize: R.sp(3.8), color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: R.wp(9.0),
          height: R.wp(9.0),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: R.wp(5.0)),
        ),
        SizedBox(width: R.wp(3.0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: R.wp(1.5), vertical: 1),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(tag, style: TextStyle(fontSize: R.sp(2.5), color: color, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: R.wp(2.0)),
                  Expanded(child: Text(title, style: TextStyle(fontSize: R.sp(4.0), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              Text(subtitle, style: TextStyle(fontSize: R.sp(3.2), color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

}
