import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/bitex_map.dart';
import 'active_delivery.dart';

class AvailableOrders extends StatefulWidget {
  const AvailableOrders({super.key});

  @override
  State<AvailableOrders> createState() => _AvailableOrdersState();
}

class _AvailableOrdersState extends State<AvailableOrders> {
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  int _selectedIndex = 0;
  LatLng _agentLocation = const LatLng(12.3050, 76.2910);

  final List<_OrderPin> _orders = const [
    _OrderPin(
      restaurant: 'Hotel Annapurna',
      restLoc: 'Main Road, KR Nagar',
      custLoc: 'Near Bus Stand, KR Nagar',
      payout: 'Rs 25.00',
      items: 'Masala Dosa x 2, Coffee x 1',
      restaurantPoint: LatLng(12.4219, 76.0200),
      customerPoint: LatLng(12.4240, 76.0230),
    ),
    _OrderPin(
      restaurant: 'Sri Venkateshwara Tiffin Centre',
      restLoc: 'Bus Stand Road, Hunsur',
      custLoc: 'Hunsur town center',
      payout: 'Rs 30.00',
      items: 'Idli x 4, Vada x 2',
      restaurantPoint: LatLng(12.3048, 76.2908),
      customerPoint: LatLng(12.3072, 76.2924),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() {
        final offset = _agentLocation.latitude == 12.3050 ? 0.0004 : -0.0004;
        _agentLocation = LatLng(12.3050 + offset, 76.2910 + offset);
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectOrder(int index) {
    setState(() => _selectedIndex = index);
    _scrollController.animateTo(
      index * R.hp(20.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          title: Text('Available Orders', style: TextStyle(fontSize: R.sp(5.0))),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.0)),
        children: [
          SizedBox(
            height: 220,
            child: BitexMap(
              center: _orders[_selectedIndex].restaurantPoint,
              showMyLocation: false,
              markers: [
                MapMarker(
                  id: 'agent',
                  position: _agentLocation,
                  type: MapMarkerType.deliveryPartner,
                  label: 'Ravi Kumar',
                ),
                ..._orders.asMap().entries.map((entry) {
                  return MapMarker(
                    id: 'order-${entry.key}',
                    position: entry.value.restaurantPoint,
                    type: MapMarkerType.restaurant,
                    label: entry.value.restaurant,
                    onTap: () => _selectOrder(entry.key),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: R.hp(2.0)),
          ..._orders.asMap().entries.map((entry) {
            final order = entry.value;
            return _buildOrderCard(
              context,
              highlighted: entry.key == _selectedIndex,
              restaurant: order.restaurant,
              restLoc: order.restLoc,
              custLoc: order.custLoc,
              payout: order.payout,
              items: order.items,
              onTap: () => _selectOrder(entry.key),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context, {
    required bool highlighted,
    required String restaurant,
    required String restLoc,
    required String custLoc,
    required String payout,
    required String items,
    required VoidCallback onTap,
  }) {
    R.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: R.hp(18.0),
        margin: EdgeInsets.only(bottom: R.hp(2.0)),
        padding: EdgeInsets.all(R.wp(4.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(R.wp(3.5)),
          border: Border.all(
            color: highlighted ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Theme.of(context).colorScheme.primary, size: R.wp(6.5)),
                SizedBox(width: R.wp(3.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant, style: TextStyle(fontSize: R.sp(4.5), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(restLoc, style: TextStyle(fontSize: R.sp(4.0), color: AppTheme.greyColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: R.wp(2.0)),
              child: Icon(Icons.arrow_downward, size: R.wp(5.0), color: Colors.grey),
            ),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green, size: R.wp(6.5)),
                SizedBox(width: R.wp(3.0)),
                Expanded(child: Text(custLoc, style: TextStyle(fontSize: R.sp(4.0), color: AppTheme.greyColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            Row(
              children: [
                Text('Payout: $payout', style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const Spacer(),
                SizedBox(
                  height: R.hp(6.5),
                  width: R.wp(35.0),
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveDelivery())),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.wp(3.0)))),
                    child: Text('Accept', style: TextStyle(fontSize: R.sp(4.5))),
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

class _OrderPin {
  final String restaurant;
  final String restLoc;
  final String custLoc;
  final String payout;
  final String items;
  final LatLng restaurantPoint;
  final LatLng customerPoint;

  const _OrderPin({
    required this.restaurant,
    required this.restLoc,
    required this.custLoc,
    required this.payout,
    required this.items,
    required this.restaurantPoint,
    required this.customerPoint,
  });
}
