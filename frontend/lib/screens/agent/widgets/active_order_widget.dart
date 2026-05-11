import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../providers/delivery_provider.dart';
import '../../../models/models.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/bitex_map.dart';

const _red = Color(0xFFE23744);
const _navy = Color(0xFF1A1A2E);

/// Active order delivery flow widget.
/// Shows a 4-step progress bar, map placeholder, and step-advance button.
class ActiveOrderWidget extends StatelessWidget {
  const ActiveOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final prov = context.watch<DeliveryProvider>();
    final order = prov.activeOrder;
    if (order == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Active order header ──────────────────────
          _buildOrderHeader(context, prov, order),
          SizedBox(height: R.hp(2.0)),
          // ── 4-step progress bar ──────────────────────
          _buildStepProgress(context, prov),
          SizedBox(height: R.hp(2.0)),
          // ── Map placeholder ──────────────────────────
          _buildMapView(context, prov, order),
          SizedBox(height: R.hp(2.0)),
          // ── Info card ────────────────────────────────
          _buildInfoCard(context, prov, order),
          SizedBox(height: R.hp(2.0)),
          // ── Advance step button ──────────────────────
          if (prov.currentStep == DeliveryStep.delivered)
            _DeliveryOtpPanel(prov: prov)
          else
            _buildStepButton(context, prov),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────
  Widget _buildOrderHeader(BuildContext context, DeliveryProvider prov, OrderModel order) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.wp(4.5)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(R.wp(4.0)),
      ),
      child: Row(
        children: [
          // Pulsing icon
          Container(
            width: R.wp(13.0),
            height: R.wp(13.0),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(prov.stepIcon, color: Theme.of(context).colorScheme.primary, size: R.wp(7.0)),
          ),
          SizedBox(width: R.wp(3.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prov.stepLabel,
                  style: TextStyle(color: Colors.white, fontSize: R.sp(4.5), fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(order.id, style: TextStyle(color: Colors.white60, fontSize: R.sp(3.5))),
              ],
            ),
          ),
          // Live timer
          Column(
            children: [
              Icon(Icons.timer, color: Colors.white60, size: R.wp(5.0)),
              Text(prov.formattedTimer, style: TextStyle(color: Colors.white, fontSize: R.sp(4.5), fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ],
      ),
    );
  }

  // ── STEP PROGRESS ─────────────────────────────────────
  Widget _buildStepProgress(BuildContext context, DeliveryProvider prov) {
    R.init(context);
    final steps = [
      (Icons.directions_bike, 'Going'),
      (Icons.takeout_dining, 'Pickup'),
      (Icons.navigation, 'Delivering'),
      (Icons.check_circle, 'Delivered'),
    ];
    final stepIdx = prov.stepIndex;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.wp(4.0), vertical: R.hp(2.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector
            final stepBefore = i ~/ 2;
            final done = stepIdx > stepBefore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 3,
                color: done ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
              ),
            );
          }
          final s = i ~/ 2;
          final done = stepIdx > s;
          final active = stepIdx == s;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: R.wp(10.0),
                height: R.wp(10.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Theme.of(context).colorScheme.primary : active ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.grey.shade100,
                  border: Border.all(color: done || active ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: done ? 0 : 2),
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check, color: Colors.white, size: R.wp(4.5))
                      : Icon(steps[s].$1, color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, size: R.wp(5.0)),
                ),
              ),
              SizedBox(height: R.hp(0.5)),
              Text(
                steps[s].$2,
                style: TextStyle(fontSize: R.sp(2.8), color: active || done ? Theme.of(context).colorScheme.primary : Colors.grey.shade500, fontWeight: active ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── MAP VIEW ──────────────────────────────────────────
  Widget _buildMapView(BuildContext context, DeliveryProvider prov, OrderModel order) {
    R.init(context);
    final agent = LatLng(prov.currentLatitude ?? 12.3050, prov.currentLongitude ?? 76.2910);
    final restaurant = LatLng(
      order.restaurantLatitude ?? 12.3048,
      order.restaurantLongitude ?? 76.2908,
    );
    final customer = LatLng(
      order.customerLatitude ?? 12.4219,
      order.customerLongitude ?? 76.0200,
    );
    final target = prov.stepIndex < 2 ? restaurant : customer;
    return SizedBox(
      height: 260,
      child: BitexMap(
        center: target,
        showMyLocation: false,
        markers: [
          MapMarker(
            id: 'agent',
            position: agent,
            type: MapMarkerType.deliveryPartner,
            label: 'Current location',
          ),
          MapMarker(
            id: prov.stepIndex < 2 ? 'restaurant' : 'customer',
            position: target,
            type: prov.stepIndex < 2 ? MapMarkerType.restaurant : MapMarkerType.customer,
            label: prov.stepIndex < 2 ? 'Pickup' : 'Customer',
          ),
        ],
      ),
    );
  }

  Widget _mapMarker(IconData icon, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        Container(width: 2, height: 8, color: color),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── INFO CARD ─────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, DeliveryProvider prov, OrderModel order) {
    R.init(context);
    final isPickup = prov.stepIndex <= 1;
    return Container(
      padding: EdgeInsets.all(R.wp(4.5)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(R.wp(3.5)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isPickup ? Icons.restaurant : Icons.person, color: Theme.of(context).colorScheme.primary, size: R.wp(6.0)),
              SizedBox(width: R.wp(3.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPickup ? 'Restaurant ${order.restaurantId.length > 4 ? order.restaurantId.substring(0,4) : order.restaurantId}' : 'Customer ${order.customerId.length > 4 ? order.customerId.substring(0,4) : order.customerId}',
                      style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isPickup ? 'Pickup Address' : (order.landmark.isNotEmpty ? order.landmark : 'Drop Address'),
                      style: TextStyle(fontSize: R.sp(3.5), color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Call button
              Container(
                width: R.wp(11.0),
                height: R.wp(11.0),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.call, color: Theme.of(context).colorScheme.primary, size: R.wp(5.5)),
              ),
            ],
          ),
          Divider(height: R.hp(2.5), color: Colors.grey.shade200),
          Row(
            children: [
              Expanded(
                child: _infoChip(Icons.inventory_2_outlined, order.orderItems.isEmpty ? 'No items' : order.orderItems.map((e) => '${e.name} x${e.quantity}').join(', '), 'Items'),
              ),
              SizedBox(width: R.wp(2.0)),
              Expanded(
                child: _infoChip(Icons.currency_rupee, '₹ ${(order.totalAmount * 0.1).clamp(20, 100).toStringAsFixed(0)}', 'Payout'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP BUTTON ───────────────────────────────────────
  Widget _buildStepButton(BuildContext context, DeliveryProvider prov) {
    R.init(context);
    final isLastStep = prov.currentStep == DeliveryStep.delivered;
    return SizedBox(
      height: R.hp(8.0),
      child: ElevatedButton(
        onPressed: () => prov.advanceStep(),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLastStep ? const Color(0xFF2ECC71) : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: isLastStep ? 6 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(3.0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isLastStep ? Icons.check_circle : Icons.arrow_forward_ios, size: R.wp(5.5)),
            SizedBox(width: R.wp(2.5)),
            Text(prov.nextStepButtonLabel, style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOtpPanel extends StatefulWidget {
  final DeliveryProvider prov;
  const _DeliveryOtpPanel({required this.prov});

  @override
  State<_DeliveryOtpPanel> createState() => _DeliveryOtpPanelState();
}

class _DeliveryOtpPanelState extends State<_DeliveryOtpPanel> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  bool _wrong = false;
  bool _done = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _controllers.map((c) => c.text).join();
    final ok = await widget.prov.confirmDeliveryOtp(otp);
    if (!mounted) return;
    if (ok) {
      setState(() => _done = true);
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => _EarningsCompleteSheet(order: widget.prov.activeOrder),
      );
    } else {
      setState(() => _wrong = true);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrong = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(_wrong ? 8 : 0, 0, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _wrong ? Colors.red : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Text('Enter Customer OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              return Container(
                width: 48,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: TextField(
                  controller: _controllers[i],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                  onChanged: (value) {
                    if (value.isNotEmpty && i < 3) FocusScope.of(context).nextFocus();
                  },
                ),
              );
            }),
          ),
          if (_wrong)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Wrong OTP', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _done ? null : _submit,
            icon: const Icon(Icons.check),
            label: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );
  }
}

class _EarningsCompleteSheet extends StatelessWidget {
  final OrderModel? order;
  const _EarningsCompleteSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final earned = ((order?.totalAmount ?? 0) * 0.22).clamp(38, 120).toStringAsFixed(0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 68),
            const SizedBox(height: 10),
            const Text('Delivery Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text('You earned ₹$earned', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Base ₹20 + Distance ₹9 + Peak bonus ₹8 + Tip ₹0'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home')),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTERS ───────────────────────────────────────

/// Paints a subtle grid to simulate a map.
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB2DFDB).withOpacity(0.4)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

/// Paints a simplified route path from pickup to drop.
class _RoutePainter extends CustomPainter {
  final Color color;
  _RoutePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shadow = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(70, 78);
    path.cubicTo(size.width * 0.3, 70, size.width * 0.6, size.height - 80, size.width - 70, size.height - 68);

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => false;
}
