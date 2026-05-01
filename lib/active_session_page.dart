import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'tracking_service.dart';
import 'shell.dart';

class ActiveSessionPage extends ConsumerStatefulWidget {
  const ActiveSessionPage({super.key});

  @override
  ConsumerState<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends ConsumerState<ActiveSessionPage> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);

    // Auto-follow during tracking
    ref.listen(trackingProvider, (previous, next) {
      if (next.route.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(next.route.last),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Elegant Background ─────────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/athletic_minimal_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // ── Subtle Map Overlay (Bottom) ────────────────────────────────────
          Positioned(
            bottom: 220,
            left: 20,
            right: 20,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: tracking.route.isNotEmpty ? tracking.route.last : const LatLng(28.6139, 77.2090),
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  style: _mapStyle,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: tracking.route,
                      color: kGreen,
                      width: 4,
                    ),
                  },
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // ── TIMER ────────────────────────────────────────────────────
                Column(
                  children: [
                    Text(
                      'ELAPSED TIME',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tracking.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                
                const Spacer(flex: 1),

                // ── MAIN DISTANCE ────────────────────────────────────────────
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withOpacity(0.25),
                            blurRadius: 40,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Text(
                        tracking.formattedDistance.replaceAll(RegExp(r'[a-zA-Z]'), '').trim(),
                        style: const TextStyle(
                          color: kGreen,
                          fontSize: 110,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -5,
                          height: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tracking.distance < 1000 ? 'METERS' : 'KILOMETERS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // ── STATS BAR ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricGlass('CALORIES', '${tracking.calculateCalories()}', kPink),
                      _metricGlass('PACE', '---', kCyan),
                      _metricGlass('STEPS', '${tracking.steps}', kGreen),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // ── CONTROLS ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (!tracking.isPaused)
                        _controlBtn(Icons.pause_rounded, 'PAUSE', kAmber, () {
                          notifier.pauseTracking();
                        })
                      else
                        _controlBtn(Icons.play_arrow_rounded, 'RESUME', kGreen, () {
                          notifier.resumeTracking();
                        }),
                      
                      _controlBtn(Icons.stop_rounded, 'STOP', kCoral, () {
                        notifier.stopTracking(ref);
                        Navigator.pop(context);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGlass(String l, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(
      children: [
        Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    ),
  );

  Widget _controlBtn(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Icon(icon, color: color, size: 36),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    ),
  );

  final String _mapStyle = '''
  [
    { "elementType": "geometry", "stylers": [ { "color": "#121212" } ] },
    { "elementType": "labels.icon", "stylers": [ { "visibility": "off" } ] },
    { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#2c2c2c" } ] },
    { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#000000" } ] }
  ]
  ''';
}
