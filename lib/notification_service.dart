import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async { return;
    tz.initializeTimeZones();
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(androandroidInit);
    
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async { return;
    final prefs = await SharedPreferences.getInstance();
    final allEnabled = prefs.getBool('notif_all') ?? true;
    if (!allEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'fit24_general',
      'General Notifications',
      channelDescription: 'Used for daily goals and activity updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(androandroidDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> scheduleDailyReminder(int id, String title, String body, int hour, int minute) async { return;
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool('notif_reminders') ?? true;
    final allEnabled = prefs.getBool('notif_all') ?? true;
    if (!remindersEnabled || !allEnabled) {
      await _plugin.cancel(id);
      return;
    }

    // await _plugin.zonedSchedule(
      id,
      title,
      body,
       _nextInstanceOfTime(hour, minute),
       const NotificationDetails(
        AndroidNotificationDetails(
          'fit24_reminders',
          'Daily Reminders',
          channelDescription: 'Reminders to keep your streak alive',
        ),
      ),
       AndroidScheduleMode.exactAllowWhileIdle,
      // UILocalNotificationDateInterpretation.absoluteTime
       // DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAll() async { return;
    await _plugin.cancelAll();
  }
}
