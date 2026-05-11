import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapMarkerType { restaurant, deliveryPartner, customer }

class MapMarker {
  final String id;
  final LatLng position;
  final MapMarkerType type;
  final String? label;
  final VoidCallback? onTap;

  const MapMarker({
    required this.id,
    required this.position,
    required this.type,
    this.label,
    this.onTap,
  });
}

class BitexMap extends StatefulWidget {
  static const LatLng krNagarCenter = LatLng(12.4219, 76.0200);
  static const LatLng hunsurCenter = LatLng(12.3050, 76.2910);
  static const LatLng serviceSw = LatLng(12.25, 75.95);
  static const LatLng serviceNe = LatLng(12.55, 76.45);

  final LatLng center;
  final List<MapMarker> markers;
  final ValueChanged<LatLng>? onLocationChanged;
  final bool showMyLocation;
  final bool interactive;
  final double initialZoom;
  final List<LatLng> polylinePoints;

  const BitexMap({
    super.key,
    this.center = krNagarCenter,
    this.markers = const [],
    this.onLocationChanged,
    this.showMyLocation = true,
    this.interactive = true,
    this.initialZoom = 14,
    this.polylinePoints = const [],
  });

  @override
  State<BitexMap> createState() => _BitexMapState();
}

class _BitexMapState extends State<BitexMap> {
  final MapController _controller = MapController();
  LatLng? _myLocation;
  bool _warnedOutside = false;

  @override
  void initState() {
    super.initState();
    if (widget.showMyLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
    }
  }

  @override
  void didUpdateWidget(covariant BitexMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _controller.move(widget.center, widget.initialZoom);
    }
  }

  Future<void> _detectLocation({bool recenter = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _controller.move(BitexMap.krNagarCenter, widget.initialZoom);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _myLocation = point);
      widget.onLocationChanged?.call(point);
      if (_isInsideServiceArea(point) || recenter) {
        _controller.move(point, widget.initialZoom);
      } else {
        _controller.move(BitexMap.krNagarCenter, widget.initialZoom);
        _showOutsideWarning();
      }
    } catch (_) {
      if (mounted) {
        _controller.move(BitexMap.krNagarCenter, widget.initialZoom);
      }
    }
  }

  bool _isInsideServiceArea(LatLng point) {
    return point.latitude >= BitexMap.serviceSw.latitude &&
        point.latitude <= BitexMap.serviceNe.latitude &&
        point.longitude >= BitexMap.serviceSw.longitude &&
        point.longitude <= BitexMap.serviceNe.longitude;
  }

  void _showOutsideWarning() {
    if (_warnedOutside || !mounted) return;
    _warnedOutside = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delivery available in Hunsur & KR Nagar only')),
    );
  }

  Marker _buildMarker(MapMarker marker) {
    final color = switch (marker.type) {
      MapMarkerType.restaurant => Colors.red,
      MapMarkerType.deliveryPartner => Colors.blue,
      MapMarkerType.customer => Colors.green,
    };
    final icon = switch (marker.type) {
      MapMarkerType.restaurant => Icons.location_pin,
      MapMarkerType.deliveryPartner => Icons.directions_bike,
      MapMarkerType.customer => Icons.person_pin_circle,
    };
    return Marker(
      point: marker.position,
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: marker.onTap,
        child: Tooltip(
          message: marker.label ?? marker.id,
          child: Icon(icon, size: 40, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMarkers = <Marker>[
      ...widget.markers.map(_buildMarker),
      if (_myLocation != null)
        Marker(
          point: _myLocation!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 26),
          ),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
              onPositionChanged: (position, hasGesture) {
                final center = position.center;
                if (center != null && hasGesture && !_isInsideServiceArea(center)) {
                  _showOutsideWarning();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bitex99.app',
              ),
              if (widget.polylinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.polylinePoints,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          if (widget.showMyLocation)
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'bitex-map-location-${hashCode}',
                onPressed: () => _detectLocation(recenter: true),
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
