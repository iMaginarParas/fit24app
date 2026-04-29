import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'profile.dart';

class ActivitySettingsPage extends ConsumerStatefulWidget {
  const ActivitySettingsPage({super.key});

  @override
  ConsumerState<ActivitySettingsPage> createState() => _ActivitySettingsPageState();
}

class _ActivitySettingsPageState extends ConsumerState<ActivitySettingsPage> {
  bool darkMap = false;
  bool audioFeedback = true;
  bool countdownTimer = false;
  bool keepScreenOn = false;
  bool autoPause = false;
  bool autoResume = true;

  @override
  void initState() {
    super.initState();
    // Start by loading from local cache for immediate feedback
    _loadLocal();
    // Also sync from profile provider if data is already available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileDataProvider).valueOrNull;
      if (profile != null) {
        _syncFromBackend(profile);
      }
    });
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMap = prefs.getBool('tracking_dark_map') ?? false;
      audioFeedback = prefs.getBool('tracking_audio_feedback') ?? true;
      countdownTimer = prefs.getBool('tracking_countdown_timer') ?? false;
      keepScreenOn = prefs.getBool('tracking_keep_screen_on') ?? false;
      autoPause = prefs.getBool('tracking_auto_pause') ?? false;
      autoResume = prefs.getBool('tracking_auto_resume') ?? true;
    });
  }

  void _syncFromBackend(Map<String, dynamic> p) {
    bool changed = false;
    final newDarkMap = p['tracking_dark_map'] as bool? ?? darkMap;
    final newAudioFeedback = p['tracking_audio_feedback'] as bool? ?? audioFeedback;
    final newCountdownTimer = p['tracking_countdown_timer'] as bool? ?? countdownTimer;
    final newKeepScreenOn = p['tracking_keep_screen_on'] as bool? ?? keepScreenOn;
    final newAutoPause = p['tracking_auto_pause'] as bool? ?? autoPause;
    final newAutoResume = p['tracking_auto_resume'] as bool? ?? autoResume;

    if (newDarkMap != darkMap) { darkMap = newDarkMap; changed = true; }
    if (newAudioFeedback != audioFeedback) { audioFeedback = newAudioFeedback; changed = true; }
    if (newCountdownTimer != countdownTimer) { countdownTimer = newCountdownTimer; changed = true; }
    if (newKeepScreenOn != keepScreenOn) { keepScreenOn = newKeepScreenOn; changed = true; }
    if (newAutoPause != autoPause) { autoPause = newAutoPause; changed = true; }
    if (newAutoResume != autoResume) { autoResume = newAutoResume; changed = true; }

    if (changed) {
      setState(() {});
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    // 1. Update Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    
    // 2. Update Backend
    try {
      await ref.read(apiServiceProvider).updateProfile({key: value});
      // Invalidate profile data to keep it in sync
      ref.invalidate(profileDataProvider);
    } catch (_) {
      // If backend fails, we keep local for now, 
      // but in a production app you might want to show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for backend updates to keep UI in sync
    ref.listen(profileDataProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        _syncFromBackend(next.value!);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Activity Settings', 
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _settingTile(
            Icons.map_outlined,
            'Dark Map',
            'Enable dark mode for your activity map. The true StepSetGo map experience',
            darkMap,
            (v) => setState(() { darkMap = v; _updateSetting('tracking_dark_map', v); }),
          ),
          _settingTile(
            Icons.settings_voice_outlined,
            'Audio Feedback',
            'Plays audio to update you about your activity progress so you dont need to keep checking the app',
            audioFeedback,
            (v) => setState(() { audioFeedback = v; _updateSetting('tracking_audio_feedback', v); }),
          ),
          _settingTile(
            Icons.timer_outlined,
            'Countdown Timer',
            '3-2-1 GO! Shows a countdown to let you get prepared before the activity starts',
            countdownTimer,
            (v) => setState(() { countdownTimer = v; _updateSetting('tracking_countdown_timer', v); }),
          ),
          _settingTile(
            Icons.stay_primary_portrait_outlined,
            'Keep Screen On',
            'Keeps your screen on throughout your activity. Useful for cyclers tracking their ride on a phone holder.',
            keepScreenOn,
            (v) => setState(() { keepScreenOn = v; _updateSetting('tracking_keep_screen_on', v); }),
          ),
          _settingTile(
            Icons.pause_rounded,
            'Auto Pause',
            'Automatically pauses the activity when you stop moving.',
            autoPause,
            (v) => setState(() { autoPause = v; _updateSetting('tracking_auto_pause', v); }),
          ),
          _settingTile(
            Icons.play_arrow_rounded,
            'Auto Resume',
            'Automatically resumes the activity when you move after you manually pause the activity. If the activity was \'Auto Paused\', it will always Auto Resume.',
            autoResume,
            (v) => setState(() { autoResume = v; _updateSetting('tracking_auto_resume', v); }),
          ),
        ],
      ),
    );
  }

  Widget _settingTile(IconData icon, String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: value,
                        onChanged: onChanged,
                        activeColor: const Color(0xFF00E5FF),
                        activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.4),
                        inactiveThumbColor: Colors.white.withOpacity(0.8),
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(desc, style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
