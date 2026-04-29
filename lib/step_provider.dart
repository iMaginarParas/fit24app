import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'points_provider.dart';

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
