import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class ProfileStats {
  final int totalSteps;
  final int totalPoints;
  final int totalSessions;
  ProfileStats({this.totalSteps = 0, this.totalPoints = 0, this.totalSessions = 0});
}

final profileStatsProvider = FutureProvider.autoDispose<ProfileStats>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final history = await api.getStepHistory(days: 30);
    final sessions = await api.getSessions();
    int sessionSteps = sessions.fold(0, (sum, s) => sum + (s['steps'] as int? ?? 0));
    return ProfileStats(
      totalSteps: (history['total_steps'] ?? 0) + sessionSteps,
      totalPoints: history['total_fit_points'] ?? 0,
      totalSessions: sessions.length,
    );
  } catch (_) {
    return ProfileStats();
  }
});
