import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

class ConfigState {
  final String googleMapsKey;
  ConfigState({this.googleMapsKey = ""});
}

class ConfigNotifier extends StateNotifier<ConfigState> {
  final ApiService _api;
  ConfigNotifier(this._api) : super(ConfigState());

  Future<void> fetchKeys() async {
    try {
      final keys = await _api.getKeys();
      state = ConfigState(
        googleMapsKey: keys['google_maps'] ?? "",
      );
    } catch (_) {
      // Fallback or keep empty
    }
  }
}

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ConfigNotifier(api);
});
