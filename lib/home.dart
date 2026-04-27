import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as flutter_ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'shell.dart';

const _method = MethodChannel('com.fit24app/steps');
const _events = EventChannel('com.fit24app/steps_stream');

// gamification
int stepsToPoints(int s) => s * 5;
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HS();
}

class _HS extends State<HomePage> with TickerProviderStateMixin {
  _S _s = _S.perm;
  int _today = 0;
  Map<String, int> _hist = {};
  StreamSubscription? _sub;
  late AnimationController _pulse;
  late AnimationController _spin;
  late AnimationController _heartAnim;
  int _disp = 0, _last = -1;
  Timer? _tick;
  static const kGoal = 10000;

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
    _heartAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _checkPerm();
  }

  Future<void> _checkPerm() async {
    if ((await Permission.activityRecognition.status).isGranted) {
      _startTracking();
      setState(() => _s = _S.hc);
    }
  }

  Future<void> _grantPerm() async {
    final st = await Permission.activityRecognition.request();
    await Permission.notification.request();
    if (st.isGranted) { _startTracking(); setState(() => _s = _S.hc); }
  }

  void _startTracking() {
    _sub = _events.receiveBroadcastStream().listen((v) {
      if (mounted) { setState(() => _today = v as int); _animTo(v as int); }
    });
    _method.invokeMethod<int>('getTodaySteps').then((v) {
      if (v != null && v > 0 && mounted) { setState(() => _today = v); _animTo(v); }
    });
    _loadHist();
  }

  Future<void> _loadHist() async {
    final r = await _method.invokeMapMethod<String, int>('getHistory', {'days': 6});
    if (r != null && mounted) setState(() => _hist = r);
  }

  Future<void> _enableHC() async {
    setState(() => _s = _S.loading);
    try {
      final h = Health();
      await h.configure();
      final ok = await h.requestAuthorization([HealthDataType.STEPS]);
      if (ok) {
        final now = DateTime.now(); final data = <String, int>{};
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
          await _loadHist();
          final tk = DateFormat('yyyy-MM-dd').format(now);
          final hcT = data[tk] ?? 0;
          if (hcT > _today && mounted) { setState(() => _today = hcT); _animTo(hcT); }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _s = _S.ready);
  }

  void _skipHC() => setState(() => _s = _S.ready);

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
    _pulse.dispose(); _spin.dispose(); _heartAnim.dispose();
    _tick?.cancel(); _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ultra-Premium Dark Background (Deep Violet to True Black)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF130B29), // Deep rich violet
            Color(0xFF000000), // Pure Black
          ],
        ),
      ),
      child: switch (_s) {
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
          Text('Every step earns Fit Points.\nStart your fitness journey today.',
              style: TextStyle(fontSize: 16,
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
            _hcBenefit(Icons.bolt_rounded, 'Instant Fit Points on past steps'),
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

  Widget _dashboard() {
    final pct = (_disp / kGoal).clamp(0.0, 1.0);
    final pts = stepsToPoints(_today);
    final lv = levelFor(_today);
    final week = _buildWeek();
    final best = week.map((d) => d.steps).fold(0, math.max);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false,
              child: _topBar(lv, pts))),
          SliverToBoxAdapter(child: _mainRingCard(pct)),
          SliverToBoxAdapter(child: _metricsRow()),
          SliverToBoxAdapter(child: _heartRateCard()),
          SliverToBoxAdapter(child: _weekSection(week, best)),
          SliverToBoxAdapter(child: _pointsCard(pts, lv)),
          SliverToBoxAdapter(child: _milestonesSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _topBar(int lv, int pts) => Padding(
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
          const Text('Fit Points',
              style: TextStyle(
                  fontSize: 11, color: cCyan, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ]),
      ),
      const SizedBox(width: 14),
      
      AvatarCircle('PG', cCyan, size: 42, online: true),
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
                        height: 8,
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

  // ── Heart rate card ───────────────────────────────────────────────────────

  Widget _heartRateCard() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        image: DecorationImage(
          image: const NetworkImage('https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=600'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(const Color(0xFF0F0B1E).withOpacity(0.85), BlendMode.srcATop), 
        )
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            AnimatedBuilder(
              animation: _heartAnim,
              builder: (_, __) => Icon(Icons.favorite_rounded,
                  color: cPink.withOpacity(0.5 + _heartAnim.value * 0.5),
                  size: 22),
            ),
            const SizedBox(width: 8),
            const Text('Heart Rate', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          Chip24('LIVE', color: cPink),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Good pace', style: TextStyle(
              fontSize: 12, color: Colors.white.withOpacity(0.7))),
          Row(children: [
            Text('96', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: cPink.withOpacity(0.8), blurRadius: 15)])),
            const SizedBox(width: 4),
            Text('BPM', style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 14),
        SizedBox(height: 60,
          child: CustomPaint(
            size: const Size(double.infinity, 60),
            painter: _HeartRatePainter(),
          )),
      ]),
    ),
  );

  // ── Week section ──────────────────────────────────────────────────────────

  Widget _weekSection(List<_Day> week, int best) {
    final max = week.map((d) => d.steps).fold(1, math.max);
    final fmt = DateFormat('yyyy-MM-dd');
    final todayKey = fmt.format(DateTime.now());

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
            const Text('Weekly Steps', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Chip24('7 Days', color: cCyan),
          ]),
          const SizedBox(height: 20),
          SizedBox(height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: week.asMap().entries.map((e) {
                final d = e.value;
                final isToday = fmt.format(d.date) == todayKey;
                final isBest = d.steps == best && best > 0;
                final frac = d.steps / max;
                final barH = math.max(6.0, 90 * frac);

                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (isBest && !isToday)
                      const Text('Best', style: TextStyle(
                          fontSize: 8, color: cAmber,
                          fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic, height: barH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isToday ? cCyan : Colors.white.withOpacity(0.15),
                        boxShadow: isToday ? [
                          BoxShadow(color: cCyan.withOpacity(0.6), blurRadius: 15)
                        ] : [],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(DateFormat('E').format(d.date).substring(0, 1),
                      style: TextStyle(fontSize: 11,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                          color: isToday ? cCyan : Colors.white.withOpacity(0.5))),
                  ]),
                ));
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

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
              Text('Fit Points', style: TextStyle(
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
            const Text('1 step = 5 pts', style: TextStyle(
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
              return Column(children: [
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
              ]);
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

// ─────────────────────────────────────────────────────────────────────────────
// HEART RATE PAINTER — Fiery Pink/Orange Gradient
// ─────────────────────────────────────────────────────────────────────────────

class _HeartRatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width; final h = size.height;

    final pts = [
      Offset(0, h * 0.6),
      Offset(w * 0.08, h * 0.6),
      Offset(w * 0.12, h * 0.2),
      Offset(w * 0.16, h * 0.9),
      Offset(w * 0.20, h * 0.5),
      Offset(w * 0.28, h * 0.55),
      Offset(w * 0.32, h * 0.15),
      Offset(w * 0.36, h * 0.85),
      Offset(w * 0.40, h * 0.5),
      Offset(w * 0.50, h * 0.58),
      Offset(w * 0.55, h * 0.25),
      Offset(w * 0.60, h * 0.9),
      Offset(w * 0.64, h * 0.5),
      Offset(w * 0.72, h * 0.55),
      Offset(w * 0.76, h * 0.18),
      Offset(w * 0.80, h * 0.88),
      Offset(w * 0.84, h * 0.52),
      Offset(w, h * 0.58),
    ];

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cpX = (prev.dx + curr.dx) / 2;
      path.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF007F), Color(0xFFFFB300), Color(0xFFFF007F)], // Pink to Orange
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    
    // Add a slight glowing shadow to the line
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFFFF007F).withOpacity(0.3)
      ..maskFilter = const flutter_ui.MaskFilter.blur(BlurStyle.normal, 8)
    );
      
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(w, h) ..lineTo(0, h) ..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFFF007F).withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
  }

  @override
  bool shouldRepaint(_) => false;
}