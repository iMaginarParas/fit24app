import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'shell.dart';

class SessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> session;
  const SessionDetailPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> routeData = session['route'] ?? [];
    final List<LatLng> route = routeData.map((p) => LatLng(
      (p['lat'] as num).toDouble(), 
      (p['lng'] as num).toDouble()
    )).toList();
    
    final dist = (session['distance'] as num?)?.toDouble() ?? 0.0;
    final dur = (session['duration'] as num?)?.toInt() ?? 0;
    final cal = (session['calories'] as num?)?.toInt() ?? 0;
    final date = DateTime.parse(session['date']);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: route.isNotEmpty ? route.first : const LatLng(0, 0),
                zoom: 15,
              ),
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              style: _mapStyle,
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: route,
                  color: kGreen,
                  width: 5,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              },
              markers: route.isEmpty ? {} : {
                Marker(
                  markerId: const MarkerId('start'),
                  position: route.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
                Marker(
                  markerId: const MarkerId('end'),
                  position: route.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
              onMapCreated: (controller) {
                if (route.isNotEmpty) {
                  // Wait a bit for the map to stabilize then fit bounds
                  Future.delayed(const Duration(milliseconds: 500), () {
                    final bounds = _getBounds(route);
                    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                  });
                }
              },
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────────
          Positioned(
            top: 50, left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),

          // ── Bottom Summary ─────────────────────────────────────────────────
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(DateFormat('MMMM d, h:mm a').format(date), 
                        style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _metric('Distance', dist < 1000 ? '${dist.toStringAsFixed(0)}m' : '${(dist/1000).toStringAsFixed(2)}km'),
                    _metric('Duration', _formatDur(dur)),
                    _metric('Calories', '$cal'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  String _formatDur(int s) {
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _metric(String l, String v) => Column(children: [
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
    const SizedBox(height: 4),
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
  ]);

  final String _mapStyle = '''
  [
    { "elementType": "geometry", "stylers": [ { "color": "#121212" } ] },
    { "elementType": "labels.icon", "stylers": [ { "visibility": "off" } ] },
    { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#2c2c2c" } ] },
    { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#000000" } ] }
  ]
  ''';
}
