import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'api_service.dart';
import 'step_provider.dart';

class ProfileStats {
  final int totalSteps;
  final int totalPoints;
  final int totalSessions;
  final int todayStepsSynced;
  ProfileStats({
    this.totalSteps = 0, 
    this.totalPoints = 0, 
    this.totalSessions = 0, 
    this.todayStepsSynced = 0
  });
}

// 1. Fetches baseline data from backend
final baseProfileStatsProvider = FutureProvider.autoDispose<ProfileStats>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final history = await api.getStepHistory(days: 30);
    final sessions = await api.getSessions();
    final todayData = await api.getTodaySteps();
    
    int sessionSteps = sessions.fold(0, (sum, s) => sum + (s['steps'] as int? ?? 0));
    int syncedToday = todayData['steps'] as int? ?? 0;
    
    return ProfileStats(
      totalSteps: (history['total_steps'] ?? 0) + sessionSteps,
      totalPoints: history['total_fit_points'] ?? 0,
      totalSessions: sessions.length,
      todayStepsSynced: syncedToday,
    );
  } catch (_) {
    return ProfileStats();
  }
});

// 2. Combines baseline with live sensor data for instant UI updates
final profileStatsProvider = Provider.autoDispose<ProfileStats>((ref) {
  final base = ref.watch(baseProfileStatsProvider).valueOrNull ?? ProfileStats();
  final liveSteps = ref.watch(liveStepProvider).valueOrNull ?? base.todayStepsSynced;
  
  final unsynced = math.max(0, liveSteps - base.todayStepsSynced);
  
  return ProfileStats(
    totalSteps: base.totalSteps + unsynced,
    totalPoints: base.totalPoints + unsynced,
    totalSessions: base.totalSessions,
    todayStepsSynced: base.todayStepsSynced,
  );
});
