import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'shell.dart';

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends ConsumerState<NotificationsSettingsPage> {
  bool _allEnabled = true;
  bool _stepGoals = true;
  bool _challenges = true;
  bool _reminders = true;
  bool _isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkPermission();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allEnabled = prefs.getBool('notif_all') ?? true;
      _stepGoals = prefs.getBool('notif_steps') ?? true;
      _challenges = prefs.getBool('notif_challenges') ?? true;
      _reminders = prefs.getBool('notif_reminders') ?? true;
    });
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _isPermissionGranted = status.isGranted;
    });
  }

  Future<void> _toggle(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    
    // Sync with Notification Service
    final notif = NotificationService();
    if (key == 'notif_reminders' || key == 'notif_all') {
      await notif.scheduleDailyReminder(100, 'Morning Walk', 'Start your day with a 15-minute walk!', 8, 0);
    }
    
    _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _permissionStatusCard(),
          const SizedBox(height: 32),
          _sectionHeader('General Settings'),
          const SizedBox(height: 12),
          _notifTile(
            'Master Toggle', 
            'Enable all notifications', 
            _allEnabled, 
            (v) => _toggle('notif_all', v),
            Icons.notifications_active_rounded,
            kTeal,
          ),
          const SizedBox(height: 32),
          _sectionHeader('Activity & Goals'),
          const SizedBox(height: 12),
          _notifTile(
            'Step Goal Reach', 
            'Notify when you reach your daily goal', 
            _stepGoals && _allEnabled, 
            _allEnabled ? (v) => _toggle('notif_steps', v) : null,
            Icons.directions_walk_rounded,
            kGreen,
          ),
          _notifTile(
            'New Challenges', 
            'Alerts for new community challenges', 
            _challenges && _allEnabled, 
            _allEnabled ? (v) => _toggle('notif_challenges', v) : null,
            Icons.emoji_events_rounded,
            kPurple,
          ),
          _notifTile(
            'Daily Reminders', 
            'Reminders to keep your streak alive', 
            _reminders && _allEnabled, 
            _allEnabled ? (v) => _toggle('notif_reminders', v) : null,
            Icons.alarm_rounded,
            kAmber,
          ),
          const SizedBox(height: 40),
          _infoText(),
        ],
      ),
    );
  }

  Widget _permissionStatusCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _isPermissionGranted ? kTeal.withOpacity(0.1) : kCoral.withOpacity(0.1),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: (_isPermissionGranted ? kTeal : kCoral).withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (_isPermissionGranted ? kTeal : kCoral).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isPermissionGranted ? Icons.check_circle_rounded : Icons.error_rounded,
          color: _isPermissionGranted ? kTeal : kCoral,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isPermissionGranted ? 'System Notifications Enabled' : 'System Notifications Disabled',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _isPermissionGranted 
              ? 'You are receiving all app updates.' 
              : 'Please enable in system settings to receive any alerts.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      )),
      if (!_isPermissionGranted)
        TextButton(
          onPressed: () async {
            await openAppSettings();
            _checkPermission();
          },
          child: const Text('ENABLE', style: TextStyle(color: kCoral, fontWeight: FontWeight.w900)),
        ),
    ]),
  );

  Widget _sectionHeader(String title) => Text(
    title.toUpperCase(), 
    style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5),
  );

  Widget _notifTile(String title, String sub, bool val, Function(bool)? onCh, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(sub, style: TextStyle(
          color: Colors.white.withOpacity(0.3), fontSize: 12)),
        trailing: Switch.adaptive(
          value: val,
          activeColor: kTeal,
          onChanged: onCh,
        ),
      ),
    );
  }

  Widget _infoText() => Text(
    'Note: Some critical security alerts or payment notifications may still be sent even if general notifications are disabled.',
    textAlign: TextAlign.center,
    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, height: 1.5),
  );
}
