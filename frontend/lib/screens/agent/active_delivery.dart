import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/bitex_map.dart';

class ActiveDelivery extends StatefulWidget {
  const ActiveDelivery({super.key});

  @override
  State<ActiveDelivery> createState() => _ActiveDeliveryState();
}

class _ActiveDeliveryState extends State<ActiveDelivery> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  bool _delivered = false;
  bool _pickedUp = false;
  Timer? _locationTimer;
  LatLng _agentLocation = BitexMap.hunsurCenter;
  static const LatLng _restaurantLocation = LatLng(12.3048, 76.2908);
  static const LatLng _customerLocation = LatLng(12.4219, 76.0200);

  @override
  void initState() {
    super.initState();
    _refreshLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _agentLocation = LatLng(position.latitude, position.longitude));
    } catch (_) {
      // Keep seeded Hunsur center as a reliable local fallback.
    }
  }

  Future<void> _openNavigation() async {
    final target = _pickedUp ? _customerLocation : _restaurantLocation;
    final uri = Uri.parse('https://maps.google.com/?daddr=${target.latitude},${target.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(R.hp(8.0)),
        child: AppBar(
          toolbarHeight: R.hp(8.0),
          title: Text('Active Delivery', style: TextStyle(fontSize: R.sp(5.5))),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: R.wp(5.0), vertical: R.hp(2.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info card
            Container(
              height: R.hp(16.0),
              padding: EdgeInsets.all(R.wp(4.0)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(R.wp(3.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: R.wp(6.0),
                        backgroundColor: Colors.grey.shade200,
                        child: Icon(Icons.person, size: R.wp(6.5), color: AppTheme.greyColor),
                      ),
                      SizedBox(width: R.wp(4.0)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer: Raju S',
                              style: TextStyle(
                                fontSize: R.sp(4.5),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'KR Nagar Railway Station',
                              style: TextStyle(
                                fontSize: R.sp(4.5),
                                color: AppTheme.greyColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionBtn(
                          context,
                          icon: Icons.call,
                          label: 'Call',
                          color: Colors.green,
                          onTap: () {},
                        ),
                      ),
                      SizedBox(width: R.wp(3.0)),
                      Expanded(
                        child: _buildActionBtn(
                          context,
                          icon: Icons.map,
                          label: 'Navigate',
                          color: Colors.blue,
                          onTap: _openNavigation,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: R.hp(2.5)),
            SizedBox(
              height: 260,
              child: BitexMap(
                center: _pickedUp ? _customerLocation : _restaurantLocation,
                showMyLocation: false,
                markers: [
                  MapMarker(
                    id: 'agent',
                    position: _agentLocation,
                    type: MapMarkerType.deliveryPartner,
                    label: 'Ravi Kumar',
                  ),
                  MapMarker(
                    id: _pickedUp ? 'customer' : 'restaurant',
                    position: _pickedUp ? _customerLocation : _restaurantLocation,
                    type: _pickedUp ? MapMarkerType.customer : MapMarkerType.restaurant,
                    label: _pickedUp ? 'Customer' : 'Sri Venkateshwara Tiffin Centre',
                  ),
                ],
              ),
            ),
            SizedBox(height: R.hp(1.5)),
            OutlinedButton.icon(
              onPressed: () => setState(() => _pickedUp = true),
              icon: const Icon(Icons.takeout_dining),
              label: Text(_pickedUp ? 'Delivery step active' : 'Mark pickup complete'),
            ),
            SizedBox(height: R.hp(2.5)),
            // Delivery OTP
            Text(
              'Enter Delivery OTP',
              style: TextStyle(fontSize: R.sp(5.5), fontWeight: FontWeight.bold),
            ),
            Text(
              'Ask customer for 6-digit OTP to complete delivery',
              style: TextStyle(fontSize: R.sp(3.5), color: AppTheme.greyColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: R.hp(2.5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _buildOtpInput(i)),
            ),
            SizedBox(height: R.hp(2.5)),
            SizedBox(
              width: double.infinity,
              height: R.hp(7.5),
              child: ElevatedButton(
                onPressed: _delivered
                    ? null
                    : () {
                        setState(() => _delivered = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Delivery completed! ₹ 25 credited.',
                              style: TextStyle(fontSize: R.sp(4.0)),
                            ),
                          ),
                        );
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) Navigator.pop(context);
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _delivered ? Colors.green : Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(R.wp(3.0)),
                  ),
                ),
                child: Text(
                  _delivered ? '✓ Delivered!' : 'Mark as Delivered',
                  style: TextStyle(fontSize: R.sp(5.0), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput(int index) {
    R.init(context);
    return SizedBox(
      width: R.wp(12.0),
      height: R.hp(8.0),
      child: TextField(
        controller: _otpControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(fontSize: R.sp(7.0), fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.wp(3.0)),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.wp(3.0)),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    R.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: R.hp(6.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(R.wp(3.0)),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: R.wp(5.5)),
            SizedBox(width: R.wp(2.0)),
            Text(
              label,
              style: TextStyle(
                fontSize: R.sp(4.0),
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

