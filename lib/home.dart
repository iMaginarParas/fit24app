import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as flutter_ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'health_service.dart';
import 'profile.dart';
import 'profile_stats_provider.dart';
import 'points_provider.dart';
import 'shell.dart';
import 'tracking_page.dart';
import 'notification_service.dart';
import 'activity.dart';

const _method = MethodChannel('com.fit24app/steps');
const _events = EventChannel('com.fit24app/steps_stream');

// gamification: 1 step = 1 point
int stepsToPoints(int s) => s;
int levelFor(int s) => (s ~/ 1500) + 1;
String rankFor(int lv) {
  if (lv < 3) return 'Rookie';
  if (lv < 7) return 'Runner';
  if (lv < 12) return 'Athlete';
  if (lv < 18) return 'Champion';
  return 'Legend';
}

enum _S { perm, hc, loading, ready }

class _Day { final DateTime date; final int steps; const _Day(this.date, this.steps); }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HS();
}

class _HS extends ConsumerState<HomePage> with TickerProviderStateMixin {
  _S _s = _S.perm;
  int _today = 0;
  Map<String, int> _hist = {};
  StreamSubscription? _sub;
  late AnimationController _pulse;
  late AnimationController _spin;
  int _disp = 0, _last = -1;
  Timer? _tick;
  Timer? _syncTimer;
  Timer? _healthSyncTimer;
  int _lastSynced = 0;
  late ScrollController _sc;
  static const kGoal = 10000;
  int _chartIdx = 0;
  final PageController _pc = PageController();

  // BOLD THEME COLORS
  static const Color cCyan = Color(0xFF00E5FF);
  static const Color cPink = Color(0xFFFF007F);
  static const Color cAmber = Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _spin = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))..repeat();
    _sc = ScrollController()..addListener(() => setState(() {}));
    _checkPerm();
    Future.microtask(() => ref.read(userPointsProvider.notifier).refresh());
  }


  Future<void> _checkPerm() async {
    final prefs = await SharedPreferences.getInstance();
    final requested = prefs.getBool('hc_requested') ?? false;

    if ((await Permission.activityRecognition.status).isGranted) {
      _startTracking();
      if (requested) {
        setState(() => _s = _S.ready);
      } else {
        setState(() => _s = _S.hc);
      }
    }
  }

  Future<void> _grantPerm() async {
    final st = await Permission.activityRecognition.request();
    await Permission.notification.request();
    if (st.isGranted) { _startTracking(); setState(() => _s = _S.hc); }
  }

  void _startTracking() {
    _sub = _events.receiveBroadcastStream().listen((v) {
      if (mounted) {
        final newSteps = v as int;
        
        // Goal Notification Logic
        final profile = ref.read(profileDataProvider).valueOrNull;
        final goal = profile?['daily_goal'] ?? 8000;
        if (newSteps >= goal && _today < goal && _today > 0) {
          NotificationService().showNotification(
            id: 200,
            title: 'Goal Achieved! 🏆',
            body: "Congratulations! You've reached your daily goal of $goal steps.",
          );
        }

        setState(() => _today = newSteps);
        _animTo(newSteps);
        if (newSteps - _lastSynced > 100) _syncToBackend();
      }
    });
    
    // Fetch initial state from backend or local
    _initSteps();

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _syncToBackend());
    _healthSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) => HealthService.syncCurrentStats());
    
    // Initial health sync
    HealthService.syncCurrentStats();
    _checkDailyPointSync();
  }

  Future<void> _checkDailyPointSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastSync = prefs.getString('last_daily_point_sync');
      
      if (lastSync != today) {
        // This is the first launch of the day, or 24h have passed.
        // Refresh the global point balance to ensure everything is synced.
        await ref.read(userPointsProvider.notifier).refresh();
        await prefs.setString('last_daily_point_sync', today);
      }
    } catch (_) {}
  }

  Future<void> _initSteps() async {
    try {
      final api = ref.read(apiServiceProvider);
      final todayData = await api.getTodaySteps();
      final backendSteps = todayData['steps'] as int? ?? 0;
      
      final localSteps = await _method.invokeMethod<int>('getTodaySteps') ?? 0;
      
      final best = math.max(backendSteps, localSteps);
      if (best > 0 && mounted) {
        setState(() => _today = best);
        _animTo(best);
        _lastSynced = best;
      }
    } catch (_) {}
    _loadHist();
  }

  Future<void> _syncToBackend() async {
    if (_today <= _lastSynced || _today == 0) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.syncSteps(_today);
      _lastSynced = _today;
    } catch (_) {}
  }

  Future<void> _loadHist() async {
    try {
      final api = ref.read(apiServiceProvider);
      final h = await api.getStepHistory(days: 7);
      final days = h['days'] as List?;
      if (days != null && mounted) {
        final Map<String, int> data = {};
        for (var d in days) {
          data[d['log_date']] = d['steps'] as int;
        }
        setState(() => _hist = data);
        return;
      }
    } catch (_) {}

    // Fallback to local
    final r = await _method.invokeMapMethod<String, int>('getHistory', {'days': 6});
    if (r != null && mounted) setState(() => _hist = r);
  }

  Future<void> _enableHC() async {
    setState(() => _s = _S.loading);
    final ok = await HealthService.connectAndSync();
    if (ok) {
       await _loadHist();
       // Initial sync of today's steps if needed
       _initSteps();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hc_requested', true);
    if (mounted) setState(() => _s = _S.ready);
  }

  void _skipHC() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hc_requested', true);
    setState(() => _s = _S.ready);
  }

  void _animTo(int t) {
    if (t == _last) return;
    _last = t; _tick?.cancel();
    final start = _disp; final diff = t - start;
    if (diff == 0) return;
    int f = 0;
    _tick = Timer.periodic(const Duration(milliseconds: 16), (tk) {
      f++;
      if (f >= 35) { if (mounted) setState(() => _disp = t); tk.cancel(); return; }
      final e = 1 - math.pow(1 - f / 35, 3).toDouble();
      if (mounted) setState(() => _disp = (start + diff * e).round());
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _sc.dispose();
    _pc.dispose();
    _tick?.cancel();
    _sub?.cancel();
    _syncTimer?.cancel();
    _healthSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: switch (_s) {
        _S.perm    => _permView(),
        _S.hc      => _hcView(),
        _S.loading => _loadView(),
        _S.ready   => _dashboard(),
      },
    );
  }

  // ── Permission views ──────────────────────────────────────────────────────

  Widget _permView() => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(children: [
      Positioned(top: -80, right: -80, child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cCyan.withOpacity(0.05),
          boxShadow: [BoxShadow(color: cCyan.withOpacity(0.15), blurRadius: 120)],
        ),
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(),
          Center(child: SizedBox(
            width: 220, height: 220,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  size: const Size(220, 220),
                  painter: _PremiumOrbPainter(0.0, _pulse.value),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_run_rounded, size: 48, color: cCyan),
                const SizedBox(height: 8),
                const Text('0', style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('Steps', style: TextStyle(
                    fontSize: 14, color: Colors.white.withOpacity(0.7))),
              ]),
            ]),
          )),
          const Spacer(),
          const Text('Track. Earn.\nLevel Up.', style: TextStyle(
              fontSize: 40, fontWeight: FontWeight.w900,
              color: Colors.white, height: 1.1, letterSpacing: -1)),
          const SizedBox(height: 14),
          Text('Every step earns Fit24 and unlocks rewards.', style: TextStyle(fontSize: 16,
                  color: Colors.white.withOpacity(0.7), height: 1.6)),
          const SizedBox(height: 48),
          GreenBtn('Allow Activity Access', onTap: _grantPerm),
          const SizedBox(height: 40),
        ]),
      )),
    ]),
  );

  Widget _hcView() => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: cPink,
                  boxShadow: [BoxShadow(color: cPink, blurRadius: 16)],
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Health Connect', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Import 30 days of history', style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.7))),
              ])),
            ]),
            const SizedBox(height: 20),
            _hcBenefit(Icons.history_rounded, 'Last 30 days of steps imported'),
            const SizedBox(height: 10),
            _hcBenefit(Icons.bolt_rounded, 'Instant Fit24 on past steps'),
            const SizedBox(height: 10),
            _hcBenefit(Icons.bar_chart_rounded, 'Full weekly & monthly charts'),
          ]),
        ),
        const Spacer(),
        GreenBtn('Connect Health Connect', onTap: _enableHC),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _skipHC,
          child: Center(child: Text('Skip for now',
              style: TextStyle(fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                  decoration: TextDecoration.underline))),
        ),
        const SizedBox(height: 40),
      ]),
    )),
  );

  Widget _hcBenefit(IconData icon, String label) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: cCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: cCyan, size: 16),
    ),
    const SizedBox(width: 12),
    Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
  ]);

  Widget _loadView() => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 52, height: 52,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: cCyan,
              backgroundColor: cCyan.withOpacity(0.2))),
      const SizedBox(height: 24),
      const Text('Importing history...', style: TextStyle(
          fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('This may take a moment', style: TextStyle(
          fontSize: 13, color: Colors.white.withOpacity(0.7))),
    ])),
  );

  // ── Dashboard ─────────────────────────────────────────────────────────────

  bool _refreshing = false;

  Widget _dashboard() {
    final pct = (_disp / kGoal).clamp(0.0, 1.0);
    final pts = ref.watch(userPointsProvider);
    final displayPts = (pts + math.max(0, _today - _lastSynced)).toInt();
    final lv = levelFor(_today);
    final week = _buildWeek();
    final best = week.map((d) => d.steps).fold(0, math.max);

    final profileAsync = ref.watch(profileDataProvider);
    final p = profileAsync.valueOrNull ?? {};
    final name = p['name'] as String? ?? 'User';



    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: cCyan,
        backgroundColor: const Color(0xFF111111),
        strokeWidth: 3,
        displacement: 40,
        onRefresh: () async {
          try {
            final method = MethodChannel('com.fit24app/steps');
            final localSteps = await method.invokeMethod<int>('getTodaySteps') ?? 0;
            final currentSteps = _hist.isNotEmpty ? (_hist.values.first) : 0; 
            if (localSteps > currentSteps) {
              await ref.read(apiServiceProvider).syncSteps(localSteps);
            }
          } catch (_) {}

          ref.invalidate(profileDataProvider);
          ref.invalidate(profileStatsProvider);
          ref.invalidate(userPointsProvider);

          await _initSteps();
          await ref.read(userPointsProvider.notifier).refresh();
          await ref.read(baseProfileStatsProvider.future);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
            CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: SafeArea(bottom: false,
                    child: _topBar(lv, displayPts, p))),
                SliverToBoxAdapter(child: _pointsCard(displayPts, lv)),
                SliverToBoxAdapter(child: _mainRingCard(pct)),
                SliverToBoxAdapter(child: _metricsRow()),
                SliverToBoxAdapter(child: _dailyStepsChart(week)),
                SliverToBoxAdapter(child: _milestonesSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingPage())),
        backgroundColor: cCyan,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
        label: const Text('Start Activity', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _topBar(int lv, int pts, Map<String, dynamic> p) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Image.network(
        'https://www.image2url.com/r2/default/images/1776158261618-440cb3d6-dcff-4851-9f4e-0d6ffc5851d8.png',
        height: 72, 
        fit: BoxFit.contain,
      ),
      const Spacer(),
      
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: Row(children: [
          Text(NumberFormat.compact().format(pts),
              style: const TextStyle(
                  fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          const Text('Fit24',
              style: TextStyle(
                  fontSize: 11, color: cCyan, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ]),
      ),
      const SizedBox(width: 14),
      
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
        child: AvatarCircle(
          (p['name'] as String? ?? 'U').substring(0, 1).toUpperCase(), 
          cCyan, 
          size: 42, 
          online: true, 
          imagePath: p['avatar_url'] as String?,
          gender: p['gender'] as String?,
        ),
      ),
    ]),
  );

  // ── Main step ring — Bold High Contrast ───────────────────────────────────

  Widget _mainRingCard(double pct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: flutter_ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), // Ultra clear glass
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 15))
              ]
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Running Activity', style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 2),
                    const Text('Today', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                  Row(children: [
                    Chip24('Today', color: cCyan, filled: true),
                    const SizedBox(width: 8),
                    Chip24('Week', color: Colors.white.withOpacity(0.2)),
                  ]),
                ]),
                const SizedBox(height: 28),
                
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => SizedBox(
                    width: 220, height: 220,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _PremiumOrbPainter(pct, _pulse.value),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(NumberFormat('#,###').format(_disp),
                          style: const TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -2)),
                        const Text('Steps', style: TextStyle(
                            fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ),
                
                const SizedBox(height: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Daily Goal', style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.7))),
                    Text('${NumberFormat('#,###').format(_disp)} / ${NumberFormat('#,###').format(kGoal)}',
                        style: const TextStyle(
                            fontSize: 13, color: cCyan, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(children: [
                      Container(height: 8, color: Colors.white.withOpacity(0.1)),
                      LayoutBuilder(builder: (c, cx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        height: 8.0,
                        width: cx.maxWidth * pct,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [cCyan, cPink]
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [BoxShadow(color: cPink.withOpacity(0.6), blurRadius: 12)],
                        ),
                      )),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Metrics row ───────────────────────────────────────────────────────────

  Widget _metricsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Expanded(child: _metricCard(
        Icons.directions_walk_rounded, cCyan,
        '${(_disp * 0.0008).toStringAsFixed(2)} km', 'Distance')), 
      const SizedBox(width: 10),
      Expanded(child: _metricCard(
        Icons.local_fire_department_rounded, cPink,
        '${(_disp * 0.05).toStringAsFixed(0)}', 'Calories')), 
      const SizedBox(width: 10),
      Expanded(child: _metricCard(
        Icons.access_time_rounded, cAmber,
        '${(_disp / 100).toStringAsFixed(0)} min', 'Active')), 
    ]),
  );

  Widget _metricCard(IconData icon, Color accent, String val, String label) =>
    Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(height: 10),
        Text(val, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: TextStyle(
            fontSize: 11, color: Colors.white.withOpacity(0.7))),
      ]),
    );


  // ── Week section (Sliding Metrics) ──────────────────────────────────────────

  Widget _dailyStepsChart(List<_Day> week) {
    return Column(
      children: [
        SizedBox(
          height: 310,
          child: PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _chartIdx = i),
            children: [
              _metricSlide(
                'Steps', 
                week, 
                (d) => d.steps.toDouble(), 
                cCyan, 
                'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600',
                'per day'
              ),
              _metricSlide(
                'Calories', 
                week, 
                (d) => (d.steps ~/ 20).toDouble(), 
                kCoral, 
                'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=600',
                'kcal avg'
              ),
              _metricSlide(
                'Distance', 
                week, 
                (d) => (d.steps * 0.75) / 1000.0, 
                kGreen, 
                'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?q=80&w=600',
                'km total',
                isKm: true
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => _dot(i == _chartIdx)),
        ),
      ],
    );
  }

  Widget _metricSlide(String title, List<_Day> week, dynamic Function(_Day) valFn, Color color, String img, String sub, {bool isKm = false}) {
    final data = week.map((d) => valFn(d).toDouble()).toList();
    final total = data.reduce((a, b) => a + b);
    final avg = total / data.length;
    
    // Improved scaling: ensure a minimum scale to avoid giant bars for tiny values, 
    // but also ensure the highest value is visible.
    final maxVal = data.fold(0.0, (m, v) => math.max(m, v));
    final chartMax = math.max(isKm ? 5.0 : 5000.0, maxVal * 1.2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          image: DecorationImage(
            image: NetworkImage(img),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isKm ? '${total.toStringAsFixed(2)} km' : '${total.round()} total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Avg: ${isKm ? avg.toStringAsFixed(2) : avg.round()} ${isKm ? "km" : "steps"}/day',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ]),
            ]),
            const SizedBox(height: 30),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(week.length, (i) {
                  final d = week[i];
                  final val = data[i];
                  final frac = val / chartMax;
                  final barH = math.max(6.0, 140 * frac);
                  final label = DateFormat('E').format(d.date).substring(0, 1);
                  final isZero = val == 0;
                  final isToday = i == week.length - 1;

                  return Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (val > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isKm ? val.toStringAsFixed(1) : (val > 1000 ? '${(val/1000).toStringAsFixed(1)}k' : val.round().toString()),
                            style: TextStyle(
                              fontSize: 9, 
                              fontWeight: FontWeight.w800, 
                              color: isToday ? color : Colors.white.withOpacity(0.9)
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 13), // Placeholder for zero values to keep alignment
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Background track
                          Container(
                            height: 140,
                            width: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          // Active bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            height: barH.toDouble(),
                            width: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  color.withOpacity(0.8),
                                  color,
                                ],
                              ),
                              boxShadow: isZero ? [] : [
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label, 
                        style: TextStyle(
                          fontSize: 12, 
                          color: isToday ? color : Colors.white.withOpacity(0.4), 
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600
                        )
                      ),
                    ]),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(
    width: active ? 16 : 8, height: 4,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: active ? Colors.white : Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(100),
    ),
  );

  // ── Points card ───────────────────────────────────────────────────────────

  Widget _pointsCard(int pts, int lv) {
    final xp = _today % 1500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(const Color(0xFF0F0B1E).withOpacity(0.85), BlendMode.srcATop), 
          )
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [cCyan, cPink]),
                boxShadow: [BoxShadow(color: cPink.withOpacity(0.5), blurRadius: 16)],
              ),
              child: const Center(child: Text('⚡', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fit24', style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.7))),
              Text(NumberFormat('#,###').format(pts),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -1)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Level $lv', style: const TextStyle(
                  fontSize: 13, color: cCyan, fontWeight: FontWeight.w800)),
              Text(rankFor(lv), style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.7))),
            ]),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            const Text('1 step = 1 Fit24 Point', style: TextStyle(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$xp / 1,500 XP to Lv ${lv + 1}',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(children: [
              Container(height: 7, color: Colors.white.withOpacity(0.1)),
              LayoutBuilder(builder: (c, cx) => AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                height: 7,
                width: cx.maxWidth * (xp / 1500).clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [cCyan, cPink]),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: cPink.withOpacity(0.6), blurRadius: 10)],
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Milestones ────────────────────────────────────────────────────────────

  Widget _milestonesSection() {
    // Bold, distinct colors for each milestone
    final milestones = [
      (1000, '1K', Icons.directions_run_rounded, const Color(0xFF00E5FF)), // Cyan
      (5000, '5K', Icons.local_fire_department_rounded, const Color(0xFFFFB300)), // Amber
      (10000, '10K', Icons.emoji_events_rounded, const Color(0xFF00FF87)), // Neon Green
      (20000, '20K', Icons.military_tech_rounded, const Color(0xFFFF007F)), // Pink
      (50000, '50K', Icons.auto_awesome_rounded, const Color(0xFFB026FF)), // Purple
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Milestones', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('${milestones.where((m) => _today >= m.$1).length} / ${milestones.length}',
                style: const TextStyle(
                    fontSize: 13, color: cCyan, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: milestones.map((m) {
              final done = _today >= m.$1;
              final accent = m.$4;
              return GestureDetector(
                onTap: () => _showMilestoneInfo(m.$2, m.$1, done),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 54, height: 54,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: done ? accent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: done ? accent : Colors.white.withOpacity(0.1),
                          width: 2),
                      boxShadow: done ? [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 16)] : [],
                    ),
                    child: Icon(m.$3, color: done ? accent : Colors.white.withOpacity(0.2), size: 24),
                  ),
                  const SizedBox(height: 7),
                  Text(m.$2, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900,
                      color: done ? accent : Colors.white.withOpacity(0.3))),
                ]),
              );
            }).toList()),
        ]),
      ),
    );
  }

  List<_Day> _buildWeek() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return [
      for (int i = 6; i >= 1; i--)
        _Day(now.subtract(Duration(days: i)),
            _hist[fmt.format(now.subtract(Duration(days: i)))] ?? 0),
      _Day(now, _today),
    ];
  }

  void _showMilestoneInfo(String label, int steps, bool done) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('$label Milestone', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requirement: $steps steps in a single day.', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text(done ? 'Status: COMPLETED ✅' : 'Status: IN PROGRESS ⏳', 
              style: TextStyle(color: done ? cCyan : Colors.white38, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Great!', style: TextStyle(color: cCyan))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM ORB PAINTER — Cyber-Athletic Neon Lights
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumOrbPainter extends CustomPainter {
  final double progress;
  final double pulse;

  _PremiumOrbPainter(this.progress, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 16; 
    final rect = Rect.fromCircle(center: c, radius: r);

    // Bold Neon Colors
    const electricCyan = Color(0xFF00E5FF);
    const hotPink = Color(0xFFFF007F);      
    const coreDark = Color(0xFF0A0815); // Almost black, deep void core

    // 1. Breathing Ambient Aura (Huge Cyan/Pink glow)
    final auraRadius = r + 25 + (pulse * 20);
    canvas.drawCircle(
      c, auraRadius,
      Paint()..shader = flutter_ui.Gradient.radial(
        c, auraRadius,
        [
          electricCyan.withOpacity(0.3 - (pulse * 0.1)), 
          hotPink.withOpacity(0.15),
          Colors.transparent
        ],
        [0.2, 0.6, 1.0],
      )
    );

    // 2. The Solid Premium Ball
    canvas.drawCircle(
      c, r,
      Paint()..shader = flutter_ui.Gradient.radial(
        Offset(c.dx - 20, c.dy - 20), r * 1.2, 
        [electricCyan.withOpacity(0.4), coreDark, Colors.black],
        [0.0, 0.6, 1.0],
      )
    );

    // 3. Unlit Track (Very dark, sleek groove)
    canvas.drawArc(
      rect, 0, 2 * math.pi, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Colors.white.withOpacity(0.05)
    );

    if (progress > 0) {
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      
      // Intense Neon Gradient for the active track
      final trackGradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweep,
        colors: const [electricCyan, hotPink, Colors.white], 
        stops: const [0.0, 0.7, 1.0],
      ).createShader(rect);

      // 4. Solid Glow Track (Massive blur for neon effect)
      canvas.drawArc(
        rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = trackGradient
          ..maskFilter = const flutter_ui.MaskFilter.blur(BlurStyle.normal, 16)
      );

      // 5. Core Solid Track (Sharp, pure light)
      canvas.drawArc(
        rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = trackGradient
      );

      // 6. Premium Glass Highlight
      canvas.drawArc(
        rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.8)
      );
    }
  }

  @override
  bool shouldRepaint(_PremiumOrbPainter o) => 
      o.progress != progress || o.pulse != pulse;
}
