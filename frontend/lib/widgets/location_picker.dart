import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'bitex_map.dart';

class LocationPickerResult {
  final LatLng location;
  final String address;

  const LocationPickerResult({
    required this.location,
    required this.address,
  });
}

class LocationPicker extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPicker({
    super.key,
    this.initialCenter = BitexMap.krNagarCenter,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final MapController _controller = MapController();
  late LatLng _selected = widget.initialCenter;
  String _address = 'Move the map to choose a delivery location';
  Timer? _reverseDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode(_selected));
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    super.dispose();
  }

  void _moveTo(LatLng point) {
    setState(() => _selected = point);
    _controller.move(point, 15);
    _reverseGeocode(point);
  }

  void _scheduleReverseGeocode(LatLng point) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocode(point);
    });
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _address = 'Finding address...');
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toStringAsFixed(7),
        'lon': point.longitude.toStringAsFixed(7),
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'com.bitex99.app'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _address = data['display_name']?.toString() ?? _fallbackAddress(point));
      } else {
        setState(() => _address = _fallbackAddress(point));
      }
    } catch (_) {
      if (mounted) setState(() => _address = _fallbackAddress(point));
    }
  }

  String _fallbackAddress(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Delivery Location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: 15,
                    onPositionChanged: (position, hasGesture) {
                      final center = position.center;
                      if (center == null) return;
                      setState(() => _selected = center);
                      if (hasGesture) _scheduleReverseGeocode(center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bitex99.app',
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 48),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _TownChip(label: 'KR Nagar', onTap: () => _moveTo(BitexMap.krNagarCenter)),
                      const SizedBox(width: 8),
                      _TownChip(label: 'Hunsur', onTap: () => _moveTo(BitexMap.hunsurCenter)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _address,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        LocationPickerResult(location: _selected, address: _address),
                      );
                    },
                    child: const Text('Confirm Location'),
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

class _TownChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TownChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.place, size: 18),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }
}
