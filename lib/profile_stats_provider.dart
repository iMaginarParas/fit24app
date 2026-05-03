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
    final history = await api.getStepHistory(days: 30);
    final remoteSessions = await api.getSessions();
    final todayData = await api.getTodaySteps();
    
    // Include local unsynced sessions
    final prefs = await SharedPreferences.getInstance();
    final localList = prefs.getStringList('gps_sessions') ?? [];
    final localSessions = localList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    
    // Differentiate sessions by ID/Date to avoid double counting
    final Map<String, dynamic> uniqueSessions = {};
    for (var s in remoteSessions) {
      uniqueSessions[s['id']?.toString() ?? s['date'].toString()] = s;
    }
    for (var s in localSessions) {
      uniqueSessions[s['id']?.toString() ?? s['date'].toString()] = s;
    }

    int extraSteps = 0;
    int extraPoints = 0;
    final remoteIds = remoteSessions.map((s) => s['id']?.toString() ?? s['date'].toString()).toSet();
    
    for (var s in localSessions) {
      final key = s['id']?.toString() ?? s['date'].toString();
      if (!remoteIds.contains(key)) {
        extraSteps += (s['steps'] as num?)?.toInt() ?? 0;
        extraPoints += (s['fit_points'] as num?)?.toInt() ?? 0;
      }
    }

    final syncedToday = (todayData['steps'] as num?)?.toInt() ?? 0;

    return ProfileStats(
      totalSteps: (history['total_steps'] ?? 0) + extraSteps,
      totalPoints: (history['total_fit_points'] ?? 0) + extraPoints,
      totalSessions: uniqueSessions.length,
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
