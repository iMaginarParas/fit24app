import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'points_provider.dart';
import 'api_service.dart';
import 'health_service.dart';
import 'profile_stats_provider.dart';

final liveStepProvider = StreamProvider<int>((ref) {
  const events = EventChannel('com.fit24app/steps_stream');
  return events.receiveBroadcastStream().map((v) => v as int);
});

final todayStepsProvider = StateProvider<int>((ref) => 0);

// A listener that syncs liveStepProvider to todayStepsProvider and updates points
final stepSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<int>>(liveStepProvider, (prev, next) {
    final oldSteps = prev?.value ?? 0;
    next.whenData((steps) {
      ref.read(todayStepsProvider.notifier).state = steps;
      
      // Instant point update
      final delta = steps - oldSteps;
      if (delta > 0 && oldSteps > 0) {
        ref.read(userPointsProvider.notifier).updateLocal(delta);
      }
    });
  });
});

// GLOBAL AUTO-SYNC: Periodically syncs steps and health data in the background
final globalSyncProvider = Provider<void>((ref) {
  int lastSynced = 0;
  Timer? debounce;

  Future<void> performSync() async {
    final steps = ref.read(todayStepsProvider);
    if (steps <= lastSynced || steps == 0) return;
    
    try {
      final api = ref.read(apiServiceProvider);
      await api.syncSteps(steps);
      lastSynced = steps;
      ref.read(userPointsProvider.notifier).refresh();
    } catch (_) {}
  }

  void sync() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), performSync);
  }

  // 1. Listen for EVERY step change for instant (debounced) sync
  ref.listen<int>(todayStepsProvider, (prev, next) {
    if (next > lastSynced) {
      sync();
    }
  });

  // 2. Periodic sync timer (every 5 minutes)
  final syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());

  // 3. Health Connect sync timer (every 15 minutes)
  final healthTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    HealthService.syncCurrentStats();
  });

  // 4. Offline session sync timer (every 15 minutes)
  final offlineTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('offline_sessions') ?? [];
      if (queue.isEmpty) return;

      final api = ref.read(apiServiceProvider);
      final remaining = <String>[];
      for (var sJson in queue) {
        try {
          await api.saveSession(jsonDecode(sJson));
        } catch (_) {
          remaining.add(sJson);
        }
      }
      await prefs.setStringList('offline_sessions', remaining);
    } catch (_) {}
  });

  // 5. Initial sync
  Future.microtask(() {
    HealthService.syncCurrentStats();
    sync();
  });

  ref.onDispose(() {
    syncTimer.cancel();
    healthTimer.cancel();
    offlineTimer.cancel();
    debounce?.cancel();
  });
});
