import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'leaderboard.dart';
import 'session_detail_page.dart';
import 'shell.dart';
import 'tracking_service.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});
  @override
  ConsumerState<ActivityPage> createState() => _AP();
}

class _AP extends ConsumerState<ActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _period = 0; // 0=Today 1=Week 2=Month
  bool _loading = true;
  List<dynamic> _history = [];
  List<Map<String, dynamic>> _sessions = [];
  int? _selIdx;
  int _totalSteps = 0;
  ActivityType _selectedType = ActivityType.running;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (mounted) setState(() => _period = _tab.index); });
    _loadData();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localList = prefs.getStringList('gps_sessions') ?? [];
      final localSessions = localList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

      final api = ref.read(apiServiceProvider);
      final remoteSessions = await api.getSessions();
      
      if (mounted) {
        setState(() {
          // Merge and sort by date
          final combined = [...localSessions, ...remoteSessions];
          // Use a Map to deduplicate by date/id if possible
          final Map<String, Map<String, dynamic>> unique = {};
          for (var s in combined) {
             final key = s['id']?.toString() ?? s['date'].toString();
             unique[key] = s;
          }
          _sessions = unique.values.toList();
          _sessions.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        });
      }
    } catch (_) {
      // Fallback to local only if remote fails
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('gps_sessions') ?? [];
      if (mounted) {
        setState(() {
          _sessions = list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getStepHistory(days: 30);
      if (mounted) {
        setState(() {
          _history = data['days'] ?? [];
          _totalSteps = data['total_steps'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  static const _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  static const _colors = [kPurple, kBlue, kTeal, kAmber, kCoral, kPurple, kGreen];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/activity_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: kGreen))
          else
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                SliverToBoxAdapter(child: _periodTabs()),
                SliverToBoxAdapter(child: _mainStepCard()),
                SliverToBoxAdapter(child: SectionHeader('Activity Totals')),
                SliverToBoxAdapter(child: _modeTotals()),
                SliverToBoxAdapter(child: SectionHeader('Daily Breakdown')),
                SliverToBoxAdapter(child: _barChart()),
                SliverToBoxAdapter(child: SectionHeader('Recent Sessions')),
                SliverToBoxAdapter(child: _sessionsList()),
                SliverToBoxAdapter(child: SectionHeader('Activity Log')),
                SliverToBoxAdapter(child: _logList()),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reports', style: TextStyle(
            fontSize: 12, color: Colors.white.withOpacity(0.35))),
        PopupMenuButton<ActivityType>(
          onSelected: (t) => setState(() => _selectedType = t),
          offset: const Offset(0, 40),
          color: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (ctx) => [
            _menuItem(ActivityType.walking, 'Walking Activity'),
            _menuItem(ActivityType.running, 'Running Activity'),
            _menuItem(ActivityType.cycling, 'Cycling Activity'),
          ],
          child: Row(children: [
            Text(_titleOf(_selectedType), style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withOpacity(0.5), size: 22),
          ]),
        ),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardPage())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGreen.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.emoji_events_rounded, size: 16, color: kGreen),
            SizedBox(width: 8),
            Text('Leaderboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kGreen)),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.notifications_outlined,
            size: 20, color: Colors.white.withOpacity(0.5)),
      ),
    ]),
  );

   Widget _modeTotals() {
    double walkDist = 0, runDist = 0, cycleDist = 0;
    int walkDur = 0, runDur = 0, cycleDur = 0;

    for (var s in _sessions) {
      final type = ActivityType.values[s['type'] as int];
      final dist = s['distance'] as double;
      final dur = s['duration'] as int;
      if (type == ActivityType.walking) { walkDist += dist; walkDur += dur; }
      else if (type == ActivityType.running) { runDist += dist; runDur += dur; }
      else if (type == ActivityType.cycling) { cycleDist += dist; cycleDur += dur; }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _modeCard('WALK', walkDist, walkDur, Icons.directions_walk_rounded, kTeal),
        const SizedBox(width: 12),
        _modeCard('RUN', runDist, runDur, Icons.directions_run_rounded, kCoral),
        const SizedBox(width: 12),
        _modeCard('CYCLE', cycleDist, cycleDur, Icons.directions_bike_rounded, kAmber),
      ]),
    );
  }

  Widget _modeCard(String label, double dist, int dur, IconData icon, Color color) => Container(
    width: 140,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(dist < 1000 ? '${dist.toStringAsFixed(0)}m' : '${(dist/1000).toStringAsFixed(1)}km', 
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      Text('${(dur/60).toStringAsFixed(0)} mins', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
    ]),
  );

  Widget _sessionsList() {
    final filtered = _sessions.where((s) => ActivityType.values[s['type'] as int] == _selectedType).toList();
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('No sessions recorded for this activity.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final s = filtered[i];
          final type = ActivityType.values[s['type'] as int];
          final dist = s['distance'] as double;
          final date = DateTime.parse(s['date']);
          
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(session: s))),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(type == ActivityType.walking ? Icons.directions_walk_rounded : 
                       type == ActivityType.running ? Icons.directions_run_rounded : 
                       Icons.directions_bike_rounded, color: kTeal, size: 18),
                  const Spacer(),
                  Text(DateFormat('MMM d').format(date), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                ]),
                const Spacer(),
                Text(dist < 1000 ? '${dist.toStringAsFixed(0)}m' : '${(dist/1000).toStringAsFixed(1)}km', 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(type.name.toUpperCase(), style: const TextStyle(color: kTeal, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _periodTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: ['Today', 'Week', 'Month'].asMap().entries.map((e) {
          final sel = _period == e.key;
          return Expanded(child: GestureDetector(
            onTap: () { _tab.animateTo(e.key); setState(() => _period = e.key); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? kGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(e.value, textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? Colors.black : Colors.white.withOpacity(0.4),
                )),
            ),
          ));
        }).toList(),
      ),
    ),
  );

  Widget _mainStepCard() {
    final today = _history.isNotEmpty ? _history.first : null;
    final steps = today != null ? today['steps'] as int : 0;
    final cal = today != null ? today['calories'] as int : 0;

    double todayDist = 0;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (var s in _sessions) {
      if (s['date'].startsWith(todayStr) && ActivityType.values[s['type'] as int] == _selectedType) {
        todayDist += s['distance'] as double;
      }
    }
    
    final isStepBased = _selectedType == ActivityType.walking;
    final displayVal = isStepBased 
        ? NumberFormat('#,###').format(steps)
        : (todayDist < 1000 ? '${todayDist.toStringAsFixed(0)}' : '${(todayDist/1000).toStringAsFixed(2)}');
    final displayUnit = isStepBased ? 'Steps' : (todayDist < 1000 ? 'Meters' : 'Kilometers');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          // Left: step/distance ring
          SizedBox(
            width: 130, height: 130,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(130, 130),
                  painter: _MiniRing(isStepBased ? steps : (todayDist).toInt(), isStepBased ? 10000 : 5000, kGreen)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(displayVal, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(displayUnit, style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.4))),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          // Right: metrics
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sideMetric('Sleep', '08:30', 'Hours', Icons.nightlight_round, kBlue),
            const SizedBox(height: 14),
            _sideMetric('Calories', '$cal', 'Kcal', Icons.local_fire_department_rounded, kCoral),
            const SizedBox(height: 14),
            _sideMetric('Training', '${steps ~/ 100}', 'Minutes', Icons.fitness_center_rounded, kGreen),
          ])),
        ]),
      ),
    );
  }

  Widget _sideMetric(String label, String val, String unit, IconData icon, Color color) =>
    Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.35))),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(val, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 3),
          Padding(padding: const EdgeInsets.only(bottom: 1),
            child: Text(unit, style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(0.35)))),
        ]),
      ]),
    ]);

  Widget _healthRow() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Expanded(child: _healthCard(
        'Water', '1.8 L', Icons.water_drop_rounded, kBlue,
        widget: _waterCircle())),
    ]),
  );

  Widget _healthCard(String label, String val, IconData icon, Color color,
      {Widget? widget}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 12, color: Colors.white.withOpacity(0.5))),
        ]),
        const SizedBox(height: 8),
        Text(val, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 8),
        if (widget != null) widget,
      ]),
    );



  Widget _waterCircle() => Center(child: SizedBox(
    width: 60, height: 60,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(60, 60),
          painter: _ArcPainter(0.54, kBlue)),
      const Text('54%', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
    ]),
  ));

   Widget _barChart() {
    final week = _history.take(7).toList().reversed.toList();
    if (week.isEmpty) return const SizedBox();
    
    final maxSteps = week.map((d) => d['steps'] as int).fold(1, math.max);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
        ),
        child: SizedBox(height: 120,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(week.length, (i) {
              final d = week[i];
              final s = d['steps'] as int;
              final frac = s / maxSteps;
              final h = math.max(8.0, 94 * frac);
              final date = DateTime.parse(d['log_date']);
              final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
              final color = _colors[i % _colors.length];
              
               return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selIdx = (_selIdx == i ? null : i)),
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (_selIdx == i)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(NumberFormat.compact().format(s), 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
                      ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 400 + i * 50),
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isToday ? null : color.withOpacity(_selIdx == i ? 1.0 : 0.5),
                        gradient: isToday ? kGreenGrad : null,
                        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
                        border: _selIdx == i ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5) : null,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(DateFormat('E').format(date).substring(0, 1), style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday ? kGreen : Colors.white.withOpacity(0.35))),
                  ]),
                ),
              ));
            }),
          ),
        ),
      ),
    );
  }

  Widget _logList() {
    if (_history.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _history.map((d) {
          final date = DateTime.parse(d['log_date']);
          final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
          final steps = d['steps'] as int;
          final cal = d['calories'] as int;
          final dist = (d['distance_m'] as int) / 1000.0;
          
          String dayLabel = DateFormat('MMM d').format(date);
          if (isToday) dayLabel = 'Today';
          else if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)))) dayLabel = 'Yesterday';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _logCard(
              dayLabel, 
              '${NumberFormat('#,###').format(steps)} steps', 
              '${dist.toStringAsFixed(1)} km • $cal cal • ${steps ~/ 100} min', 
              isToday ? kGreen : kBlue, 
              isToday ? Icons.directions_run_rounded : Icons.directions_walk_rounded, 
              isToday
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _logCard(String day, String steps, String meta,
      Color color, IconData icon, bool isToday) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isToday ? color.withOpacity(0.35) : kBorder),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(day, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isToday ? color : Colors.white)),
            Text(steps, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ]),
          const SizedBox(height: 4),
          Text(meta, style: TextStyle(
              fontSize: 11, color: Colors.white.withOpacity(0.35))),
        ])),
      ]),
    );

  PopupMenuItem<ActivityType> _menuItem(ActivityType t, String label) => PopupMenuItem(
    value: t,
    child: Row(children: [
      Icon(t == ActivityType.walking ? Icons.directions_walk_rounded : 
           t == ActivityType.running ? Icons.directions_run_rounded : 
           Icons.directions_bike_rounded, size: 18, color: _selectedType == t ? kGreen : Colors.white.withOpacity(0.5)),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(
        color: _selectedType == t ? kGreen : Colors.white,
        fontWeight: _selectedType == t ? FontWeight.w800 : FontWeight.w500,
      )),
    ]),
  );

  String _titleOf(ActivityType t) => t == ActivityType.walking ? 'Walking Activity' : 
                                    t == ActivityType.running ? 'Running Activity' : 
                                    'Cycling Activity';
}

class _MiniRing extends CustomPainter {
  final int steps, goal;
  final Color color;
  _MiniRing(this.steps, this.goal, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 10
          ..color = color.withOpacity(0.08));
    final pct = (steps / goal).clamp(0.0, 1.0);
    final sweep = 2 * math.pi * pct;
    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2, endAngle: -math.pi / 2 + sweep,
            colors: [color.withOpacity(0.4), color],
          ).createShader(rect));
  }
  @override bool shouldRepaint(_MiniRing o) => o.steps != steps;
}

class _ArcPainter extends CustomPainter {
  final double pct; final Color color;
  _ArcPainter(this.pct, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 7
          ..color = color.withOpacity(0.1));
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 7
          ..strokeCap = StrokeCap.round..color = color);
  }
  @override bool shouldRepaint(_) => false;
}
