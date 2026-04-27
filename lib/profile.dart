import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_state.dart';
import 'onboarding.dart';
import 'shell.dart';

const _kBaseUrl = 'https://fit24bc-production.up.railway.app';

// ── Profile data provider ─────────────────────────────────────────────────────
final profileDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(accessTokenProvider);
  if (token.isEmpty) return {};
  final prefs = await SharedPreferences.getInstance();
  try {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/profile/me'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await prefs.setString('profile_data', jsonEncode(data));
      return data;
    }
  } catch (_) {}
  final cached = prefs.getString('profile_data');
  if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
  return {};
});

// ─────────────────────────────────────────────────────────────────────────────
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone        = ref.watch(authProvider).valueOrNull?.phone ?? '';
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: kGreen, strokeWidth: 2)),
        error: (_, __) => _body(context, ref, phone, {}),
        data: (p) => _body(context, ref, phone, p),
      ),
    );
  }

  Widget _body(BuildContext ctx, WidgetRef ref, String phone,
      Map<String, dynamic> p) =>
      CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: _header(ctx, ref, p))),
          SliverToBoxAdapter(child: _profileHero(phone, p)),
          SliverToBoxAdapter(child: _fitnessStats(p)),
          SliverToBoxAdapter(child: _statsRow()),
          SliverToBoxAdapter(child: _weeklyProgress()),
          SliverToBoxAdapter(child: _settingsSection(ctx, ref, p)),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      );

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _header(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          const Text('Profile', style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          const Spacer(),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder)),
            child: Icon(Icons.notifications_outlined,
                size: 20, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _openEditSheet(ctx, ref, p),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder)),
              child: Icon(Icons.edit_rounded,
                  size: 18, color: Colors.white.withOpacity(0.5)),
            ),
          ),
        ]),
      );

  // ── Profile hero ────────────────────────────────────────────────────────────
  Widget _profileHero(String phone, Map<String, dynamic> p) {
    final g    = (p['gender'] as String? ?? '').toLowerCase();
    final emoji = g == 'female' ? '👩' : '🧍';
    final city  = p['city'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [kGreen.withOpacity(0.18), kTeal.withOpacity(0.08), kCard],
          ),
          border: Border.all(color: kGreen.withOpacity(0.25)),
        ),
        child: Column(children: [
          Row(children: [
            Stack(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, gradient: kGreenGrad,
                  boxShadow: [BoxShadow(
                      color: kGreen.withOpacity(0.4), blurRadius: 20)],
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 36))),
              ),
              Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: kGreen,
                        border: Border.all(color: kBg, width: 2.5)),
                    child: const Icon(Icons.check, size: 11, color: Colors.black),
                  )),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _displayName(p, phone),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(phone, style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.4))),
                    const SizedBox(height: 6),
                    Row(children: [
                      Chip24(_levelLabel(p), color: kAmber),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(children: [
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: kGreen)),
                          const SizedBox(width: 5),
                          const Text('Active', style: TextStyle(
                              fontSize: 11, color: kGreen,
                              fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _bioChip(Icons.location_on_rounded,
                city.isNotEmpty ? city : 'Set location'),
            const SizedBox(width: 10),
            _bioChip(Icons.calendar_today_rounded, 'Since Apr 2026'),
          ]),
        ]),
      ),
    );
  }

  String _displayName(Map<String, dynamic> p, String phone) {
    final name = (p['name'] as String? ?? '').trim();
    if (name.isNotEmpty) return name;
    return phone.isNotEmpty ? phone : 'Fit24 User';
  }

  String _levelLabel(Map<String, dynamic> p) {
    final goal = (p['daily_goal'] as int? ?? 8000);
    if (goal >= 15000) return 'Lv 10 · Legend';
    if (goal >= 10000) return 'Lv 7 · Champion';
    if (goal >= 7000) return 'Lv 5 · Athlete';
    return 'Lv 3 · Runner';
  }

  Widget _bioChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: kBorder),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white.withOpacity(0.35)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 11, color: Colors.white.withOpacity(0.45))),
    ]),
  );

  // ── Fitness profile cards ───────────────────────────────────────────────────
  Widget _fitnessStats(Map<String, dynamic> p) {
    final age    = p['age']       as int?;
    final weight = p['weight_kg'] as num?;
    final height = p['height_cm'] as int?;
    final goal   = p['daily_goal'] as int? ?? 8000;
    final freq   = p['exercise_freq'] as String? ?? '—';
    final focus  = (p['focus_areas'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('FITNESS PROFILE', style: TextStyle(
              fontSize: 10, color: kGreen,
              letterSpacing: 2, fontWeight: FontWeight.w700)),
        ),
        Row(children: [
          Expanded(child: _infoCard('Age',
              age != null ? '$age yrs' : '—', kBlue, Icons.cake_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _infoCard('Weight',
              weight != null ? '${weight}kg' : '—', kAmber, Icons.monitor_weight_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _infoCard('Height',
              height != null ? '${height}cm' : '—', kPurple, Icons.height_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _infoCard('Daily Goal', '$goal steps', kGreen, Icons.flag_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _infoCard('Frequency', freq, kCoral, Icons.repeat_rounded)),
        ]),
        if (focus.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.my_location_rounded, size: 15, color: kTeal),
                const SizedBox(width: 6),
                Text('Focus Areas', style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: focus.map((f) =>
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: kTeal.withOpacity(0.3)),
                    ),
                    child: Text(f, style: const TextStyle(
                        fontSize: 12, color: kTeal, fontWeight: FontWeight.w600)),
                  )).toList()),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _infoCard(String label, String val, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(
              fontSize: 10, color: Colors.white.withOpacity(0.35))),
        ]),
      );

  // ── Stats row ───────────────────────────────────────────────────────────────
  Widget _statsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Expanded(child: _statCard('247,850', 'Total Steps', kGreen)),
      const SizedBox(width: 10),
      Expanded(child: _statCard('1,239,250', 'Fit Points', kAmber)),
      const SizedBox(width: 10),
      Expanded(child: _statCard('23 🔥', 'Day Streak', kCoral)),
    ]),
  );

  Widget _statCard(String val, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(val, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 9, color: Colors.white.withOpacity(0.4),
          fontWeight: FontWeight.w600, height: 1.3)),
    ]),
  );

  // ── Weekly progress ─────────────────────────────────────────────────────────
  Widget _weeklyProgress() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('This Week', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('7 / 7 days', style: TextStyle(
              fontSize: 13, color: kGreen, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
            final done = e.key < 6;
            final isToday = e.key == 6;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? kGreen : (isToday ? kGreen.withOpacity(0.2) : kCard2),
                border: Border.all(
                    color: isToday ? kGreen : (done ? Colors.transparent : kBorder),
                    width: 2),
                boxShadow: done
                    ? [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 10)]
                    : [],
              ),
              child: Center(child: done
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : Text(e.value, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isToday ? kGreen : Colors.white.withOpacity(0.3)))),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('49,536 steps this week',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
          Text('+12% vs last week',
              style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ),
  );

  // ── Settings ────────────────────────────────────────────────────────────────
  Widget _settingsSection(BuildContext ctx, WidgetRef ref,
      Map<String, dynamic> p) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('SETTINGS', style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(0.3),
                letterSpacing: 2, fontWeight: FontWeight.w700)),
          ),
          Container(
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: Column(children: [
              _tapItem(Icons.person_outline_rounded, kGreen,
                  'Edit Fitness Profile', '', () => _openEditSheet(ctx, ref, p)),
              _divider(),
              _settingItem(Icons.flag_rounded, kGreen, 'Daily Goal',
                  '${p['daily_goal'] ?? 8000} steps'),
              _divider(),
              _settingItem(Icons.notifications_rounded, kBlue, 'Notifications', 'On'),
              _divider(),
              _settingItem(Icons.lock_rounded, kPurple, 'Privacy', ''),
              _divider(),
              _settingItem(Icons.help_outline_rounded, Colors.white38, 'Help & Support', ''),
              _divider(),
              _settingItem(Icons.star_rounded, kAmber, 'Rate Fit24', ''),
            ]),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (_) => AlertDialog(
                  backgroundColor: kCard,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('Sign Out', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
                  content: Text('Are you sure you want to sign out?',
                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: TextStyle(
                            color: Colors.white.withOpacity(0.5)))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out', style: TextStyle(
                            color: kCoral, fontWeight: FontWeight.w800))),
                  ],
                ),
              );
              if (ok == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(kOnboardingDoneKey);
                await prefs.remove('profile_data');
                await ref.read(authProvider.notifier).signOut();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kCoral.withOpacity(0.2)),
              ),
              child: _settingItem(Icons.logout_rounded, kCoral, 'Sign Out', ''),
            ),
          ),
        ]),
      );

  Widget _tapItem(IconData icon, Color color, String label, String val,
      VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: _settingItem(icon, color, label, val));

  Widget _settingItem(IconData icon, Color color, String label, String val) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(
              fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500))),
          if (val.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 6),
                child: Text(val, style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.35)))),
          Icon(Icons.chevron_right_rounded, size: 18,
              color: Colors.white.withOpacity(0.2)),
        ]),
      );

  Widget _divider() => Divider(height: 1, thickness: 1,
      indent: 18, endIndent: 18, color: Colors.white.withOpacity(0.04));

  void _openEditSheet(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: p, providerRef: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final WidgetRef providerRef;
  const _EditProfileSheet({required this.profile, required this.providerRef});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late String       _name;
  late String       _gender;
  late int          _age;
  late double       _weight;
  late int          _height;
  late int          _goal;
  late String       _freq;
  late List<String> _focus;
  late List<String> _exTypes;
  late String       _city;
  bool _saving = false;

  static const _goals = [3000,4000,5000,6000,7000,8000,9000,10000,12000,15000,20000];
  static const _freqOpts  = ['0–1 Workouts','2–4 Workouts','+5 Workouts'];
  static const _focusOpts = ['arm','chest','flat belly','bubble booty','quads','back','shoulders','full body'];
  static const _typeOpts  = ['yoga','meditation','gym','cycling','running','walking','swimming','home workout','rope skipping','hiit','pilates','crossfit'];

  @override
  void initState() {
    super.initState();
    final p  = widget.profile;
    _name    = p['name']          as String? ?? '';
    _gender  = p['gender']        as String? ?? '';
    _age     = p['age']           as int?    ?? 26;
    _weight  = (p['weight_kg']    as num?    ?? 70).toDouble();
    _height  = p['height_cm']     as int?    ?? 170;
    _goal    = p['daily_goal']    as int?    ?? 8000;
    _freq    = p['exercise_freq'] as String? ?? '';
    _focus   = List<String>.from(p['focus_areas']    ?? []);
    _exTypes = List<String>.from(p['exercise_types'] ?? []);
    _city    = p['city']          as String? ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final token = ref.read(accessTokenProvider);
    try {
      final res = await http.patch(
        Uri.parse('$_kBaseUrl/profile/me'),
        headers: {'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'name': _name, 'gender': _gender, 'age': _age, 'weight_kg': _weight,
          'height_cm': _height, 'daily_goal': _goal, 'exercise_freq': _freq,
          'focus_areas': _focus, 'exercise_types': _exTypes, 'city': _city,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_data', res.body);
        ref.invalidate(profileDataProvider);
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              const Text('Edit Profile', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _saving ? null : kGreenGrad,
                    color: _saving ? kCard : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: Colors.black)),
                ),
              ),
            ]),
          ),
          Expanded(child: ListView(controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              // Name
              _sec('Name'),
              Container(
                decoration: BoxDecoration(color: kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder)),
                child: TextField(
                  controller: TextEditingController(text: _name)
                    ..selection = TextSelection.collapsed(offset: _name.length),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 16, color: Colors.white,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Your full name',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: kGreen.withOpacity(0.7), size: 20),
                  ),
                  onChanged: (v) => _name = v,
                ),
              ),

              // Gender
              _sec('Gender'),
              Row(children: ['male', 'female'].map((g) {
                final sel = _gender == g;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: g == 'male' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? kGreen.withOpacity(0.12) : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sel ? kGreen : kBorder,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(
                        g == 'male' ? '🧍  Male' : '🧍‍♀️  Female',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                            color: sel ? kGreen : Colors.white)),
                  ),
                ));
              }).toList()),

              // Age
              _sec('Age'),
              _numRow('$_age', 'yrs',
                  () => setState(() { if (_age > 10) _age--; }),
                  () => setState(() { if (_age < 100) _age++; })),

              // Weight
              _sec('Weight (kg)'),
              _numRow(_weight.toStringAsFixed(1), 'kg',
                  () => setState(() { if (_weight > 30) _weight = (_weight * 10 - 1) / 10; }),
                  () => setState(() { if (_weight < 200) _weight = (_weight * 10 + 1) / 10; })),

              // Height
              _sec('Height (cm)'),
              _numRow('$_height', 'cm',
                  () => setState(() { if (_height > 100) _height--; }),
                  () => setState(() { if (_height < 250) _height++; })),

              // Daily goal
              _sec('Daily Step Goal'),
              Wrap(spacing: 8, runSpacing: 8,
                children: _goals.map((g) {
                  final sel = _goal == g;
                  return GestureDetector(
                    onTap: () => setState(() => _goal = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? kGreen.withOpacity(0.12) : kCard,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: sel ? kGreen : kBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text('$g', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: sel ? kGreen : Colors.white.withOpacity(0.5))),
                    ),
                  );
                }).toList()),

              // Frequency
              _sec('Exercise Frequency'),
              ..._freqOpts.map((f) {
                final sel = _freq == f;
                return GestureDetector(
                  onTap: () => setState(() => _freq = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: sel ? kGreen.withOpacity(0.1) : kCard,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: sel ? kGreen : kBorder,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(f, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: sel ? kGreen : Colors.white)),
                  ),
                );
              }),

              // Focus areas
              _sec('Focus Areas'),
              Wrap(spacing: 8, runSpacing: 8,
                children: _focusOpts.map((f) {
                  final sel = _focus.contains(f);
                  return GestureDetector(
                    onTap: () => setState(
                            () => sel ? _focus.remove(f) : _focus.add(f)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? kTeal.withOpacity(0.12) : kCard,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: sel ? kTeal : kBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text(f, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? kTeal : Colors.white.withOpacity(0.5))),
                    ),
                  );
                }).toList()),

              // Exercise types
              _sec('Exercise Types'),
              Wrap(spacing: 8, runSpacing: 8,
                children: _typeOpts.map((t) {
                  final sel = _exTypes.contains(t);
                  return GestureDetector(
                    onTap: () => setState(
                            () => sel ? _exTypes.remove(t) : _exTypes.add(t)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? kPurple.withOpacity(0.12) : kCard,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: sel ? kPurple : kBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text(t, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? kPurple : Colors.white.withOpacity(0.5))),
                    ),
                  );
                }).toList()),

              // City
              _sec('City'),
              Container(
                decoration: BoxDecoration(color: kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder)),
                child: TextField(
                  controller: TextEditingController(text: _city)
                    ..selection = TextSelection.collapsed(offset: _city.length),
                  style: const TextStyle(
                      fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter your city',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => _city = v,
                ),
              ),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(t.toUpperCase(), style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
  );

  Widget _numRow(String val, String unit, VoidCallback dec, VoidCallback inc) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        child: Row(children: [
          GestureDetector(onTap: dec,
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kCard2,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.remove_rounded,
                    color: Colors.white, size: 18))),
          Expanded(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(val, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.35)))),
          ])),
          GestureDetector(onTap: inc,
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded, color: kGreen, size: 18))),
        ]),
      );
}