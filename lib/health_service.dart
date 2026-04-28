import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class HealthService {
  static const _method = MethodChannel('com.fit24app/steps');

  static Future<bool> connectAndSync() async {
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization([HealthDataType.STEPS]);
      if (ok) {
        final now = DateTime.now(); 
        final data = <String, int>{};
        for (int i = 0; i <= 30; i++) {
          final s = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
          final e = i == 0 ? now : s.add(const Duration(days: 1));
          try {
            final v = await h.getTotalStepsInInterval(s, e);
            if (v != null && v > 0) data[DateFormat('yyyy-MM-dd').format(s)] = v;
          } catch (_) {}
        }
        if (data.isNotEmpty) {
          await _method.invokeMethod('saveHistory', {'data': data});
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hc_requested', true);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<void> syncCurrentSteps() async {
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization([HealthDataType.STEPS]);
      if (ok) {
        final now = DateTime.now();
        // Start of day in local time (midnight)
        final start = DateTime(now.year, now.month, now.day);
        final steps = await h.getTotalStepsInInterval(start, now);
        if (steps != null && steps > 0) {
          await _method.invokeMethod('updateTodaySteps', {'steps': steps});
        }
      }
    } catch (_) {}
  }

  static Future<bool> isAuthorized() async {
    try {
      final h = Health();
      await h.configure();
      return await h.hasPermissions([HealthDataType.STEPS]) ?? false;
    } catch (_) {
      return false;
    }
  }
}
