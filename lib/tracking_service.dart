import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'voice_service.dart';
import 'api_service.dart';
import 'profile.dart';

enum ActivityType { walking, running, cycling }

class TrackingState {
  final bool isTracking;
  final bool isPaused;
  final bool isAutoPaused;
  final ActivityType type;
  final List<LatLng> route;
  final double distance;
  final int duration;
  final int steps;
  final int calories;

  TrackingState({
    this.isTracking = false,
    this.isPaused = false,
    this.isAutoPaused = false,
    this.type = ActivityType.walking,
    this.route = const [],
    this.distance = 0,
    this.duration = 0,
    this.steps = 0,
    this.calories = 0,
  });

  TrackingState copyWith({
    bool? isTracking,
    bool? isPaused,
    bool? isAutoPaused,
    ActivityType? type,
    List<LatLng>? route,
    double? distance,
    int? duration,
    int? steps,
    int? calories,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      type: type ?? this.type,
      route: route ?? this.route,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
    );
  }

  String get formattedDistance {
    if (distance < 1000) return '${distance.toStringAsFixed(0)}m';
    return '${(distance / 1000).toStringAsFixed(2)}km';
  }

  String get formattedDuration {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int calculatePoints() {
    switch (type) {
      case ActivityType.walking: return steps; // 1 step = 1 point
      case ActivityType.running: return distance.toInt(); // 1 meter = 1 point
      case ActivityType.cycling: return distance.toInt(); // 1 meter = 1 point
    }
  }

  int calculateCalories() {
    final km = distance / 1000;
    switch (type) {
      case ActivityType.walking: return (km * 60).toInt();
      case ActivityType.running: return (km * 90).toInt();
      case ActivityType.cycling: return (km * 45).toInt();
    }
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final VoiceService _voice;
  TrackingNotifier(this._voice) : super(TrackingState());

  static const _method = MethodChannel('com.fit24app/steps');
  static const _event = EventChannel('com.fit24app/steps_stream');

  StreamSubscription<Position>? _sub;
  StreamSubscription? _stepSub;
  Timer? _timer;
  int _startSteps = 0;

  Future<void> startTracking(ActivityType type) async {
    if (state.isTracking) return;
    
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    // Load Settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final useAudio = prefs.getBool('tracking_audio_feedback') ?? true;
    final useWakelock = prefs.getBool('tracking_keep_screen_on') ?? false;
    final useAutoPause = prefs.getBool('tracking_auto_pause') ?? false;
    final useAutoResume = prefs.getBool('tracking_auto_resume') ?? true;

    if (useWakelock) WakelockPlus.enable();

    state = TrackingState(isTracking: true, type: type);
    if (useAudio) {
      await _voice.speak("Starting ${type.name} activity. Let's get moving!");
    }

    // Capture initial position
    try {
      final startPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final initialLatLng = LatLng(startPos.latitude, startPos.longitude);
      state = state.copyWith(route: [initialLatLng]);
    } catch (_) {}

    // Initial steps
    if (type != ActivityType.cycling) {
      try {
        _startSteps = await _method.invokeMethod<int>('getTodaySteps') ?? 0;
        _stepSub = _event.receiveBroadcastStream().listen((s) {
          if (s is int && !state.isPaused) {
            state = state.copyWith(steps: (s - _startSteps).clamp(0, 1000000));
          }
        });
      } catch (_) {}
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      // Auto-Pause / Auto-Resume Logic
      if (useAutoPause) {
        if (pos.speed < 0.5 && !state.isPaused) {
          state = state.copyWith(isPaused: true, isAutoPaused: true);
          if (useAudio) _voice.speak("Activity auto-paused.");
        } else if (pos.speed >= 0.5 && state.isPaused) {
          // If it was auto-paused, it always resumes.
          // If it was manually paused, it only resumes if useAutoResume is true.
          if (state.isAutoPaused || useAutoResume) {
            state = state.copyWith(isPaused: false, isAutoPaused: false);
            if (useAudio) _voice.speak("Activity resumed.");
          }
        }
      }

      if (state.isPaused) return;

      final latLng = LatLng(pos.latitude, pos.longitude);
      double newDistance = state.distance;
      
      if (state.route.isNotEmpty) {
        final last = state.route.last;
        final d = ll.Distance().as(ll.LengthUnit.Meter, 
          ll.LatLng(last.latitude, last.longitude), 
          ll.LatLng(latLng.latitude, latLng.longitude));
        
        // Voice milestones (every 1km)
        if (useAudio && (newDistance + d) ~/ 1000 > newDistance ~/ 1000) {
          final totalKm = ((newDistance + d) / 1000).toStringAsFixed(1);
          _voice.speak("Distance: $totalKm kilometers.");
        }

        newDistance += d;
      }
      
      state = state.copyWith(
        route: [...state.route, latLng],
        distance: newDistance,
      );
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!state.isPaused) {
        state = state.copyWith(duration: state.duration + 1);
      }
    });
  }

  void pauseTracking() {
    if (state.isTracking && !state.isPaused) {
      state = state.copyWith(isPaused: true, isAutoPaused: false);
      _voice.speak("Activity paused.");
    }
  }

  void resumeTracking() {
    if (state.isTracking && state.isPaused) {
      state = state.copyWith(isPaused: false, isAutoPaused: false);
      _voice.speak("Resuming activity.");
    }
  }

  Future<void> stopTracking(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final useAudio = prefs.getBool('tracking_audio_feedback') ?? true;

    if (useAudio) {
      await _voice.speak("Activity stopped. Well done on your progress!");
    }

    WakelockPlus.disable();

    _sub?.cancel();
    _stepSub?.cancel();
    _timer?.cancel();
    
    final session = {
      'date': DateTime.now().toIso8601String(),
      'type': state.type.index,
      'distance': state.distance,
      'duration': state.duration,
      'steps': state.steps,
      'calories': calculateCalories(state.distance, state.type),
      'fit_points': state.calculatePoints(),
      'route': state.route.map((l) => {'lat': l.latitude, 'lng': l.longitude}).toList(),
    };

    // Save session locally for "Activity" review (Legacy support)
    if (state.distance > 10) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final sessionsJson = prefs.getStringList('gps_sessions') ?? [];
        sessionsJson.insert(0, jsonEncode(session));
        if (sessionsJson.length > 20) sessionsJson.removeLast();
        await prefs.setStringList('gps_sessions', sessionsJson);
        
        // SYNC TO BACKEND
        await _syncSession(session, ref);
      } catch (_) {}
    }
    
    state = state.copyWith(isTracking: false, isPaused: false, isAutoPaused: false);
  }

  Future<void> _syncSession(Map<String, dynamic> session, WidgetRef ref) async {
    final api = ref.read(apiServiceProvider);
    final prefs = await SharedPreferences.getInstance();
    
    try {
      await api.saveSession(session);
      // If success, check if there are other pending sessions to clear
      await _clearOfflineQueue(api, prefs);
    } catch (e) {
      // If fails, add to offline queue
      final queue = prefs.getStringList('offline_sessions') ?? [];
      queue.add(jsonEncode(session));
      await prefs.setStringList('offline_sessions', queue);
    }
  }

  Future<void> _clearOfflineQueue(ApiService api, SharedPreferences prefs) async {
    final queue = prefs.getStringList('offline_sessions') ?? [];
    if (queue.isEmpty) return;

    final remaining = <String>[];
    for (var sJson in queue) {
      try {
        await api.saveSession(jsonDecode(sJson));
      } catch (_) {
        remaining.add(sJson);
      }
    }
    await prefs.setStringList('offline_sessions', remaining);
  }

  int calculateCalories(double dist, ActivityType type) {
    final km = dist / 1000;
    switch (type) {
      case ActivityType.walking: return (km * 60).toInt();
      case ActivityType.running: return (km * 90).toInt();
      case ActivityType.cycling: return (km * 45).toInt();
    }
  }

  void setType(ActivityType type) {
    state = state.copyWith(type: type);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stepSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  final voice = ref.watch(voiceServiceProvider);
  return TrackingNotifier(voice);
});

