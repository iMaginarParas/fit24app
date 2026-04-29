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
        final stepData = <String, int>{};
        
        // Fetch 30 days of history
        for (int i = 0; i <= 30; i++) {
          final s = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
          final e = i == 0 ? now : s.add(const Duration(days: 1));
          
          try {
            // 1. Steps
            final steps = await h.getTotalStepsInInterval(s, e);
            if (steps != null && steps > 0) {
              stepData[DateFormat('yyyy-MM-dd').format(s)] = steps;
            }

            // 2. Calories & Distance (Optional: sync to backend stats)
            // For now we prioritize steps for the main history table
          } catch (_) {}
        }

        if (stepData.isNotEmpty) {
          await _method.invokeMethod('saveHistory', {'data': stepData});
        }

        await syncCurrentStats();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hc_requested', true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> syncCurrentStats() async {
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization(_types);
      if (ok) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        
        // 1. Steps
        final steps = await h.getTotalStepsInInterval(start, now);
        if (steps != null && steps > 0) {
          await _method.invokeMethod('updateTodaySteps', {'steps': steps});
        }
        
        // 2. Distance
        final distPoints = await h.getHealthDataFromTypes(
          startTime: start, endTime: now, types: [HealthDataType.DISTANCE_DELTA]);
        double totalDist = 0;
        for (var p in distPoints) {
          if (p.value is NumericHealthValue) totalDist += (p.value as NumericHealthValue).numericValue;
        }

        // 3. Calories
        final calPoints = await h.getHealthDataFromTypes(
          startTime: start, endTime: now, types: [HealthDataType.ACTIVE_ENERGY_BURNED]);
        double totalCals = 0;
        for (var p in calPoints) {
          if (p.value is NumericHealthValue) totalCals += (p.value as NumericHealthValue).numericValue;
        }

        // We can save these to SharedPreferences for the UI to display "Health Data" sources
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('hc_today_distance', totalDist);
        await prefs.setDouble('hc_today_calories', totalCals);
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
