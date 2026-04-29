import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

final userPointsProvider = StateNotifierProvider<UserPointsNotifier, int>((ref) {
  return UserPointsNotifier(ref);
});

class UserPointsNotifier extends StateNotifier<int> {
  final Ref ref;
  UserPointsNotifier(this.ref) : super(0);

  Future<void> refresh() async {
    try {
      final api = ref.read(apiServiceProvider);
      final stats = await api.getStats();
      state = stats['total_fit_points'] ?? 0;
    } catch (_) {}
  }

  void updateLocal(int delta) {
    state += delta;
  }
}
