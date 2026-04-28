import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'auth_state.dart';
import 'health_service.dart';
import 'onboarding.dart';
import 'points_provider.dart';
import 'profile_stats_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'shell.dart';
import 'notifications_settings_page.dart';

// API base (managed by ApiService)


final profileDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  try {
    final data = await api.getProfile();
    await prefs.setString('profile_data', jsonEncode(data));
    return data;
  } catch (_) {}
  final cached = prefs.getString('profile_data');
  if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
  return {};
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(authProvider).valueOrNull?.phone ?? '';
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kTeal, strokeWidth: 2)),
        error: (_, __) => _body(context, ref, phone, {}),
        data: (p) => _body(context, ref, phone, p),
      ),
    );
  }

  Widget _body(BuildContext ctx, WidgetRef ref, String phone, Map<String, dynamic> p) => RefreshIndicator(
    color: kTeal,
    backgroundColor: const Color(0xFF1A1A1A),
    strokeWidth: 3,
    onRefresh: () async {
      // 1. Sync steps to backend
      try {
        const method = MethodChannel('com.fit24app/steps');
        final localSteps = await method.invokeMethod<int>('getTodaySteps') ?? 0;
        if (localSteps > 0) {
          await ref.read(apiServiceProvider).syncSteps(localSteps);
        }
      } catch (_) {}

      // 2. Invalidate and reload
      ref.invalidate(profileDataProvider);
      ref.invalidate(profileStatsProvider);
      ref.invalidate(userPointsProvider);
      await ref.read(profileDataProvider.future);
      await ref.read(profileStatsProvider.future);
    },
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: Container(
              color: kBg.withOpacity(0.9),
              padding: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top),
              child: _topHeader(ctx, ref, p),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _heroProfile(ctx, ref, phone, p)),
        SliverToBoxAdapter(child: _achievementsSection()),
        SliverToBoxAdapter(child: _statsGrid(ref)),
        SliverToBoxAdapter(child: _settingsGroup('Account Settings', [
          _settingTile(Icons.person_outline_rounded, kTeal, 'Edit Profile', 'Manage your info', 
            () => _openEditSheet(ctx, ref, p)),
          _settingTile(Icons.lock_outline_rounded, kPurple, 'Privacy & Security', '', null),
        ])),
        SliverToBoxAdapter(child: _settingsGroup('Permissions & Data', [
          _settingTile(Icons.favorite_rounded, kPink, 'Health Connect', 'Sync your fitness history', 
            () => _manageHealthConnect(ctx)),
          _settingTile(Icons.notifications_none_rounded, kBlue, 'Notifications', 'Manage alerts', 
            () => _manageNotifications(ctx)),
        ])),
        SliverToBoxAdapter(child: _settingsGroup('Support & Feedback', [
          _settingTile(Icons.help_outline_rounded, Colors.white38, 'Help Center', '', null),
          _settingTile(Icons.star_border_rounded, kAmber, 'Rate Fit24', 'Version 1.0.2', null),
          _settingTile(Icons.logout_rounded, kCoral, 'Sign Out', '', () => _signOut(ctx, ref)),
        ])),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    ),
  );

  Widget _topHeader(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
    child: Row(children: [
      const Text('My Profile', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
      const Spacer(),
      _circleBtn(Icons.edit_note_rounded, () => _openEditSheet(ctx, ref, p)),
    ]),
  );

  Widget _heroProfile(BuildContext ctx, WidgetRef ref, String phone, Map<String, dynamic> p) {
    final name = p['name'] as String? ?? 'Elite User';
    final city = p['city'] as String? ?? 'San Francisco, CA';
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(children: [
        GestureDetector(
          onTap: () => _pickAndUploadImage(ctx, ref),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kTeal.withOpacity(0.3), width: 2),
                boxShadow: [BoxShadow(color: kTeal.withOpacity(0.15), blurRadius: 40, spreadRadius: 5)],
              ),
            ),
            AvatarCircle(
              name.substring(0, math.min(2, name.length)).toUpperCase(), 
              kTeal, size: 90, online: true, 
              imagePath: p['avatar_url'] as String?,
              gender: p['gender'] as String?,
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _openEditSheet(ctx, ref, p),
          child: Text(name, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.location_on_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text(city, style: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: kTeal.withOpacity(0.2)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, size: 14, color: kTeal),
            SizedBox(width: 6),
            Text('FIT24 PRO', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: kTeal, letterSpacing: 1)),
          ]),
        ),
      ]),
    );
  }

  Widget _achievementsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 10, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ACHIEVEMENTS', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
            const Text('4 / 12', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: kTeal)),
          ],
        ),
      ),
      SizedBox(
        height: 110,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            _badgeCard('Early Bird', Icons.wb_sunny_rounded, kAmber, true),
            _badgeCard('Century Club', Icons.emoji_events_rounded, kGreen, true),
            _badgeCard('Marathoner', Icons.directions_run_rounded, kBlue, true),
            _badgeCard('Streak Master', Icons.bolt_rounded, kCoral, true),
            _badgeCard('Global Ranker', Icons.public_rounded, kPurple, false),
            _badgeCard('Iron Cyclist', Icons.directions_bike_rounded, kTeal, false),
          ],
        ),
      ),
    ],
  );

  Widget _badgeCard(String name, IconData icon, Color color, bool earned) => Container(
    width: 90,
    margin: const EdgeInsets.only(right: 12),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: earned ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: earned ? color.withOpacity(0.4) : Colors.white.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: earned ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15)] : null,
        ),
        child: Icon(icon, color: earned ? color : Colors.white.withOpacity(0.15), size: 28),
      ),
      const SizedBox(height: 8),
      Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, 
          color: earned ? Colors.white : Colors.white.withOpacity(0.2))),
    ]),
  );

  Widget _statsGrid(WidgetRef ref) {
    final statsAsync = ref.watch(profileStatsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kTeal, strokeWidth: 2)),
        error: (_, __) => const SizedBox(),
        data: (s) => Row(children: [
          Expanded(child: _minimalStat(NumberFormat.compact().format(s.totalSteps), 'Steps', kTeal)),
          const SizedBox(width: 12),
          Expanded(child: _minimalStat(NumberFormat.compact().format(s.totalPoints), 'Points', kAmber)),
          const SizedBox(width: 12),
          Expanded(child: _minimalStat(s.totalSessions.toString(), 'Sessions', kBlue)),
        ]),
      ),
    );
  }

  Widget _minimalStat(String val, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(children: [
      Text(val, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _settingsGroup(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 24, 24, 12),
        child: Text(title.toUpperCase(), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(children: children),
      ),
    ],
  );

  Widget _settingTile(IconData icon, Color color, String title, String subtitle, VoidCallback? onTap) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
    subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(
        fontSize: 12, color: Colors.white.withOpacity(0.3))) : null,
    trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 20),
  );

  Future<void> _manageHealthConnect(BuildContext ctx) async {
    final authorized = await HealthService.isAuthorized();
    if (authorized) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Health Connect is already connected!'), backgroundColor: kTeal),
        );
      }
      return;
    }

    final ok = await HealthService.connectAndSync();
    if (ok && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Health Connect synced successfully!'), backgroundColor: kTeal),
      );
    }
  }

  Future<void> _manageNotifications(BuildContext ctx) async {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => const NotificationsSettingsPage()));
  }

  Future<void> _pickAndUploadImage(BuildContext ctx, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;
      
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Uploading profile picture...'), duration: Duration(seconds: 2)),
        );
      }
      
      final api = ref.read(apiServiceProvider);
      await api.uploadAvatar(image.path);
      
      ref.invalidate(profileDataProvider);
      
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: kTeal),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: kCard,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
    ),
  );

  void _openEditSheet(BuildContext ctx, WidgetRef ref, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: p, providerRef: ref),
    );
  }

  Future<void> _signOut(BuildContext ctx, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to end your session?', 
          style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), 
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sign Out', style: TextStyle(color: kCoral, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kOnboardingDoneKey);
      await prefs.remove('profile_data');
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

// ── EDIT PROFILE SHEET (Keeping existing logic but slightly refining UI) ──────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final WidgetRef providerRef;
  const _EditProfileSheet({required this.profile, required this.providerRef});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late String _name;
  late String _gender;
  late int _age;
  late double _weight;
  late int _height;
  late int _goal;
  late String _city;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = p['name'] as String? ?? '';
    _gender = p['gender'] as String? ?? '';
    _age = p['age'] as int? ?? 26;
    _weight = (p['weight_kg'] as num? ?? 70).toDouble();
    _height = p['height_cm'] as int? ?? 170;
    _goal = p['daily_goal'] as int? ?? 8000;
    _city = p['city'] as String? ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.updateProfile({
        'name': _name, 'gender': _gender, 'age': _age, 'weight_kg': _weight,
        'height_cm': _height, 'daily_goal': _goal, 'city': _city,
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_data', jsonEncode(data));
      ref.invalidate(profileDataProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.9, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              const Text('Edit Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              const Spacer(),
              _saveBtn(),
            ]),
          ),
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 24), children: [
            _field('FULL NAME', _name, (v) => _name = v),
            _field('CITY', _city, (v) => _city = v),
            const SizedBox(height: 10),
            _genderSelector(),
            const SizedBox(height: 20),
            _statEdit('Age', '$_age', () => setState(() => _age--), () => setState(() => _age++)),
            _statEdit('Weight (kg)', _weight.toStringAsFixed(1), () => setState(() => _weight -= 0.5), () => setState(() => _weight += 0.5)),
            _statEdit('Height (cm)', '$_height', () => setState(() => _height--), () => setState(() => _height++)),
          ])),
        ]),
      ),
    );
  }

  Widget _saveBtn() => GestureDetector(
    onTap: _saving ? null : _save,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(14)),
      child: _saving 
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
        : const Text('Save', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
    ),
  );

  Widget _field(String label, String initial, Function(String) onCh) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
    const SizedBox(height: 8),
    TextField(
      controller: TextEditingController(text: initial)..selection = TextSelection.collapsed(offset: initial.length),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      onChanged: onCh,
      decoration: InputDecoration(
        filled: true, fillColor: kCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    const SizedBox(height: 16),
  ]);

  Widget _genderSelector() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('GENDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _genderBtn('Male', Icons.male_rounded, kBlue)),
      const SizedBox(width: 12),
      Expanded(child: _genderBtn('Female', Icons.female_rounded, kPink)),
    ]),
  ]);

  Widget _genderBtn(String g, IconData i, Color c) {
    final sel = _gender.toLowerCase() == g.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.15) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? c.withOpacity(0.5) : Colors.white10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: sel ? c : Colors.white.withOpacity(0.3), size: 18),
          const SizedBox(width: 8),
          Text(g, style: TextStyle(color: sel ? Colors.white : Colors.white.withOpacity(0.3), fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }


  Widget _statEdit(String l, String v, VoidCallback onMin, VoidCallback onPlus) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const Spacer(),
      _roundBtn(Icons.remove, onMin),
      const SizedBox(width: 16),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(width: 16),
      _roundBtn(Icons.add, onPlus),
    ]),
  );

  Widget _roundBtn(IconData i, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: kCard, shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
      child: Icon(i, color: Colors.white, size: 16),
    ),
  );
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) => false;
}