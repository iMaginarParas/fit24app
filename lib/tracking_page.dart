import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'active_session_page.dart';
import 'tracking_service.dart';
import 'activity_settings_page.dart';
import 'activity.dart';
import 'history_page.dart';
import 'profile.dart';
import 'shell.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _useDarkMap = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _determinePosition();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useDarkMap = prefs.getBool('tracking_dark_map') ?? true;
    });
  }

  void _startWithCountdown(TrackingNotifier notifier, TrackingState tracking) async {
    final prefs = await SharedPreferences.getInstance();
    final useCountdown = prefs.getBool('tracking_countdown_timer') ?? false;

    if (!useCountdown) {
      _startFinal(notifier, tracking);
      return;
    }

    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 1) {
        t.cancel();
        setState(() => _countdown = 0);
        _startFinal(notifier, tracking);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _startFinal(TrackingNotifier notifier, TrackingState tracking) async {
    await notifier.startTracking(tracking.type);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionPage()));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16),
      );
    }
  }

  void _reCenter() async {
    final position = await Geolocator.getCurrentPosition();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);

    // Auto-follow during tracking
    ref.listen(trackingProvider, (previous, next) {
      if (next.isTracking && next.route.isNotEmpty) {
        final lastPos = next.route.last;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(lastPos),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Map Layer ──────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.6139, 77.2090), // Default to New Delhi
                zoom: 16,
              ),
              onMapCreated: (c) {
                _mapController = c;
                if (_currentPosition != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition!, 16),
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              style: _useDarkMap ? _mapStyle : null,
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: tracking.route,
                  color: kTeal,
                  width: 6,
                ),
              },
            ),
          ),

          // ── Top Bar ( diseño exacto de la imagen ) ─────────────────────────
          Positioned(
            top: 60, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _topCircularBtn(Icons.close_rounded, () => Navigator.pop(context)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('GPS Acquired', style: TextStyle(
                      color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                _topCircularBtn(Icons.my_location_rounded, _reCenter),
              ],
            ),
          ),

          // ── Session Flow ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Pill (1000 steps = 1.25 coins)
                if (!tracking.isTracking)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('1 meter = 1 Fit24 Point ', style: TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withOpacity(0.5)),
                    ]),
                  ),

                // Metrics Panel (Visible when tracking)
                if (tracking.isTracking) _metricsOverlay(tracking),

                // Bottom Navigation / Control Panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40)],
                  ),
                  child: Column(children: [
                    // Tabs (Walk, Run, Cycle)
                    if (!tracking.isTracking) _activityTabs(tracking, notifier),
                    const SizedBox(height: 30),
                    // Main GO Button & Side buttons
                    _mainControlRow(tracking, notifier),
                  ]),
                ),
              ],
            ),
          ),


          // ── Countdown Overlay ──────────────────────────────────────────────
          if (_countdown > 0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: kTeal,
                      fontSize: 160,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topCircularBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  Widget _activityTabs(TrackingState tracking, TrackingNotifier notifier) => Row(
    children: ActivityType.values.map((t) {
      final sel = tracking.type == t;
      final label = t == ActivityType.walking ? 'Walk' : t == ActivityType.running ? 'Run' : 'Cycle';
      final icon = t == ActivityType.walking ? Icons.directions_walk_rounded :
      t == ActivityType.running ? Icons.directions_run_rounded :
      Icons.directions_bike_rounded;

      return Expanded(
        child: GestureDetector(
          onTap: () => notifier.setType(t),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: sel ? Colors.white : Colors.white.withOpacity(0.3), size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                  color: sel ? Colors.white : Colors.white.withOpacity(0.3),
                  fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 2, width: sel ? 90 : 0,
              color: kTeal,
            ),
          ]),
        ),
      );
    }).toList(),
  );

  Widget _mainControlRow(TrackingState tracking, TrackingNotifier notifier) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
        child: _subIcon(Icons.calendar_today_outlined, 'History'),
      ),
      GestureDetector(
        onTap: () async {
          if (!tracking.isTracking) {
            _startWithCountdown(notifier, tracking);
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionPage()));
          }
        },
        child: Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: kTeal,
          ),
          child: const Center(child: Text('GO', style: TextStyle(
              color: Colors.black, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1))),
        ),
      ),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitySettingsPage())),
        child: _subIcon(Icons.settings_outlined, 'Settings'),
      ),
    ],
  );


  Widget _subIcon(IconData icon, String label) => Column(children: [
    Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 24),
    ),
    const SizedBox(height: 8),
    Text(label, style: TextStyle(
        color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
  ]);

  Widget _metricsOverlay(TrackingState tracking) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.9),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _metric('Distance', tracking.formattedDistance),
      _metric('Duration', tracking.formattedDuration),
      _metric('Calories', '${tracking.calculateCalories()}'),
    ]),
  );

  Widget _metric(String l, String v) => Column(children: [
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
    const SizedBox(height: 4),
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
  ]);

  final String _mapStyle = '''
  [
    { "elementType": "geometry", "stylers": [ { "color": "#121212" } ] },
    { "elementType": "labels.icon", "stylers": [ { "visibility": "off" } ] },
    { "elementType": "labels.text.fill", "stylers": [ { "color": "#757575" } ] },
    { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#2c2c2c" } ] },
    { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#000000" } ] }
  ]
  ''';
}
