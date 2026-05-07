import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'api_service.dart';
import 'step_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  try {
    final api = ref.watch(apiServiceProvider);
    
    // FETCH REAL TOTALS FROM BACKEND (Includes Referrals, Spin-Win, etc.)
    final statsData = await api.getStats();
    final todayData = await api.getTodaySteps();
    
    // Include local unsynced sessions (if any haven't hit the server yet)
    final prefs = await SharedPreferences.getInstance();
    final localList = prefs.getStringList('gps_sessions') ?? [];
    final localSessions = localList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    
    // Note: getStats already includes remote sessions. 
    // We only need to check if there are NEW local sessions not yet synced.
    // However, for total points accuracy, getStats is our source of truth.

    final syncedToday = (todayData['steps'] as num?)?.toInt() ?? 0;

    return ProfileStats(
      totalSteps: (statsData['total_steps'] as num?)?.toInt() ?? 0,
      totalPoints: (statsData['total_fit_points'] as num?)?.toInt() ?? 0,
      totalSessions: (statsData['total_sessions'] as num?)?.toInt() ?? 0,
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
