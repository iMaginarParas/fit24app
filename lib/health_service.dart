import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class HealthService {
  static const _method = MethodChannel('com.fit24app/steps');

  static List<HealthDataType> get _types => [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static Future<bool> connectAndSync() async {
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization(_types);
      if (ok) {
        final now = DateTime.now(); 
        final data = <String, int>{};
        
        // Fetch 30 days of history
        for (int i = 0; i <= 30; i++) {
          final s = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
          final e = i == 0 ? now : s.add(const Duration(days: 1));
          try {
            final v = await h.getTotalStepsInInterval(s, e);
            if (v != null && v > 0) {
              data[DateFormat('yyyy-MM-dd').format(s)] = v;
            }
          } catch (_) {}
        }

        if (data.isNotEmpty) {
          await _method.invokeMethod('saveHistory', {'data': data});
        }

        // Also sync today's latest specifically
        await syncCurrentSteps();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hc_requested', true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> syncCurrentSteps() async {
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization(_types);
      if (ok) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        
        // We prioritize steps for the main counter
        final steps = await h.getTotalStepsInInterval(start, now);
        if (steps != null && steps > 0) {
          await _method.invokeMethod('updateTodaySteps', {'steps': steps});
        }
        
        // Distance and calories can be fetched if needed for other UI elements
        // final dist = await h.getTotalStepsInInterval(start, now, dataType: HealthDataType.DISTANCE);
      }
    } catch (_) {}
  }

  static Future<bool> isAuthorized() async {
    try {
      final h = Health();
      await h.configure();
      return await h.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }
}
