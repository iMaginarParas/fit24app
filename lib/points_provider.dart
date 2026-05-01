import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

final userPointsProvider = StateNotifierProvider<UserPointsNotifier, int>((ref) {
  return UserPointsNotifier(ref);
});

class UserPointsNotifier extends StateNotifier<int> {
  final Ref ref;
  UserPointsNotifier(this.ref) : super(0) {
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('cached_total_points') ?? 0;
  }

  Future<void> refresh() async {
    try {
      final api = ref.read(apiServiceProvider);
      final stats = await api.getStats();
      final total = stats['total_fit_points'] ?? 0;
      state = total;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cached_total_points', total);
    } catch (_) {}
  }

  void updateLocal(int delta) {
    state += delta;
  }
}
