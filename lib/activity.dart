import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'api_service.dart';
import 'leaderboard.dart';
import 'session_detail_page.dart';
import 'shell.dart';
import 'tracking_service.dart';
import 'notifications_settings_page.dart';
import 'step_provider.dart';
import 'health_service.dart';
import 'points_provider.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});
  @override
  ConsumerState<ActivityPage> createState() => _AP();
}

class _AP extends ConsumerState<ActivityPage> with SingleTickerProviderStateMixin {
  late String _currentTime;
  Timer? _clockTimer;
  late TabController _tab;
  int _period = 0;
  List<dynamic> _history = [];
  List<dynamic> _sessions = [];
  bool _loading = true;
  int _totalSteps = 0;
  ActivityType? _selectedType = ActivityType.walking;
  int? _selIdx;
  late ScrollController _sc;
  int _chartIdx = 0;
  final PageController _pc = PageController();
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (mounted) setState(() => _period = _tab.index); });
    _sc = ScrollController();
    _currentTime = _formatTime(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        final now = _formatTime(DateTime.now());
        if (now != _currentTime) setState(() => _currentTime = now);
      }
    });
    _sc = ScrollController()..addListener(() => setState(() {}));
    _loadData();
    _loadSessions();
  }

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

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
          // Map remote sessions to have 'date' if they only have 'created_at'
          final mappedRemote = remoteSessions.map((s) {
            final map = Map<String, dynamic>.from(s as Map);
            if (map['date'] == null && map['created_at'] != null) {
              map['date'] = map['created_at'];
            }
            return map;
          }).toList();

          final combined = [...localSessions, ...mappedRemote];
          // Use a Map to deduplicate by date/id if possible
          final Map<String, Map<String, dynamic>> unique = {};
          for (var s in combined) {
             final key = s['id']?.toString() ?? s['date'].toString();
             unique[key] = s;
          }
          _sessions = unique.values.toList();
          _sessions.sort((a, b) => DateTime.parse(b['date'] ?? DateTime.now().toIso8601String())
            .compareTo(DateTime.parse(a['date'] ?? DateTime.now().toIso8601String())));
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
  void dispose() { 
    _tab.dispose(); 
    _sc.dispose();
    _pc.dispose();
    _clockTimer?.cancel();
    super.dispose(); 
  }

  static const _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  static const _colors = [kPurple, kBlue, kTeal, kAmber, kCoral, kPurple, kGreen];

  @override
  Widget build(BuildContext context) {
    final liveSteps = ref.watch(liveStepProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: kBg,
      body: RefreshIndicator(
        color: kGreen,
        backgroundColor: const Color(0xFF111111),
        strokeWidth: 3,
        displacement: 40,
        onRefresh: () async {
          try {
            await HealthService.syncCurrentStats();
            final method = MethodChannel('com.fit24app/steps');
            final localSteps = await method.invokeMethod<int>('getTodaySteps') ?? 0;
            final currentSteps = _history.isNotEmpty ? ((_history.first['steps'] as num?)?.toInt() ?? 0) : 0;
            if (localSteps > currentSteps) {
              await ref.read(apiServiceProvider).syncSteps(localSteps);
            }
          } catch (_) {}
          await _loadData();
          await _loadSessions();
        },
        child: Stack(
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
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  if (notification.metrics.pixels < 0) {
                    setState(() => _dragOffset = notification.metrics.pixels);
                  } else {
                    if (_dragOffset != 0) setState(() => _dragOffset = 0);
                  }
                }
                if (notification is ScrollEndNotification) {
                  setState(() => _dragOffset = 0);
                }
                return false;
              },
              child: Transform.translate(
                offset: Offset(0, -_dragOffset),
                child: CustomScrollView(
                  controller: _sc,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                    SliverToBoxAdapter(child: _mainStepCard(liveSteps)),
                    SliverToBoxAdapter(child: _buildActivityChart()),
                    SliverToBoxAdapter(child: SectionHeader('Activity Totals')),
                    SliverToBoxAdapter(child: _modeTotals()),
                    SliverToBoxAdapter(child: SectionHeader('Recent Sessions')),
                    SliverToBoxAdapter(child: _sessionsList()),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reports', style: TextStyle(
            fontSize: 12, color: Colors.white.withOpacity(0.35))),
        PopupMenuButton<ActivityType?>(
          onSelected: (t) => setState(() => _selectedType = t),
          offset: const Offset(0, 40),
          color: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: ActivityType.walking, child: Text('Walking')),
            const PopupMenuItem(value: ActivityType.running, child: Text('Running')),
            const PopupMenuItem(value: ActivityType.cycling, child: Text('Cycling')),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_titleOf(_selectedType!), style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
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
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsPage())),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Icon(Icons.notifications_outlined,
              size: 20, color: Colors.white.withOpacity(0.5)),
        ),
      ),
    ]),
  );

   Widget _modeTotals() {
    double dist = 0; int dur = 0; int steps = 0;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var s in _sessions) {
      if (s['date'].startsWith(todayStr)) {
        final type = ActivityType.values[(s['type'] as num).toInt()];
        if (type == _selectedType) {
          dist += (s['distance'] as num?)?.toDouble() ?? 0.0;
          dur += (s['duration'] as num?)?.toInt() ?? 0;
          steps += (s['steps'] as num?)?.toInt() ?? 0;
        }
      }
    }

    Color color = _selectedType == ActivityType.walking ? kTeal :
                  _selectedType == ActivityType.running ? kCoral : kAmber;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _modeCard('DISTANCE', dist, Icons.straighten_rounded, color, isDist: true),
        const SizedBox(width: 12),
        _modeCard('DURATION', dur.toDouble(), Icons.timer_rounded, color, isDur: true),
        const SizedBox(width: 12),
        _modeCard('STEPS', steps.toDouble(), Icons.directions_walk_rounded, color, isSteps: true),
      ]),
    );
  }

  Widget _modeCard(String label, double val, IconData icon, Color color, {bool isDist = false, bool isDur = false, bool isSteps = false}) {
    String valStr = '';
    String subStr = '';
    if (isDist) {
      valStr = val < 1000 ? val.toStringAsFixed(0) : (val/1000).toStringAsFixed(1);
      subStr = val < 1000 ? 'meters' : 'km';
    } else if (isDur) {
      valStr = (val/60).toStringAsFixed(0);
      subStr = 'mins';
    } else if (isSteps) {
      valStr = val.toInt().toString();
      subStr = 'steps';
    }

    return Container(
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
        Text(valStr, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(subStr, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
      ]),
    );
  }

  Widget _sessionsList() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filtered = _sessions.where((s) => 
      s['date'].startsWith(todayStr) && 
      ActivityType.values[(s['type'] as num).toInt()] == _selectedType
    ).toList();
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder)),
          child: Center(
            child: Column(children: [
              Icon(Icons.history_rounded, color: Colors.white.withOpacity(0.05), size: 40),
              const SizedBox(height: 12),
              Text('No ${_selectedType?.name} sessions yet', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13)),
            ]),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final s = filtered[i];
        final type = ActivityType.values[(s['type'] as num).toInt()];
        final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
        final date = DateTime.parse(s['date']);
        final steps = (s['steps'] as num?)?.toInt() ?? 0;
        final dur = (s['duration'] as num?)?.toInt() ?? 0;
        final color = type == ActivityType.walking ? kTeal : type == ActivityType.running ? kCoral : kAmber;
        
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(session: s))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(type == ActivityType.walking ? Icons.directions_walk_rounded : 
                     type == ActivityType.running ? Icons.directions_run_rounded : 
                     Icons.directions_bike_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dist < 1000 ? '${dist.toStringAsFixed(0)}m' : '${(dist/1000).toStringAsFixed(2)}km', 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                Text('${(dur/60).toStringAsFixed(1)} mins • $steps steps', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ])),
              Text(DateFormat('MMM d').format(date), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
            ]),
          ),
        );
      },
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

  Widget _mainStepCard(int liveSteps) {
    final todayLog = _history.isNotEmpty ? _history.first : null;
    final dailySteps = todayLog != null ? (todayLog['steps'] as num?)?.toInt() ?? 0 : 0;
    final bestSteps = math.max(dailySteps, liveSteps);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    int filteredSteps = 0;
    double filteredDist = 0;
    int filteredCal = 0;

    // Add session data for the selected type
    for (var s in _sessions) {
      if (s['date'].startsWith(todayStr)) {
        final type = ActivityType.values[(s['type'] as num).toInt()];
        if (_selectedType == type) {
          // If it's a session, use its direct stats
          filteredDist += (s['distance'] as num?)?.toDouble() ?? 0.0;
          filteredCal += (s['calories'] as num?)?.toInt() ?? 0;
          filteredSteps += (s['steps'] as num?)?.toInt() ?? 0;
        }
      }
    }

    // Add background steps if walking is selected
    if (_selectedType == ActivityType.walking) {
      filteredSteps += dailySteps;
      filteredDist += (dailySteps * 0.75); // rough estimate
      filteredCal += (dailySteps ~/ 20);
    }

    double totalDistKm = filteredDist / 1000.0;
    int totalCal = filteredCal;

    final displayVal = (totalDistKm < 1 ? filteredDist.toStringAsFixed(0) : totalDistKm.toStringAsFixed(2));
    final displayUnit = (totalDistKm < 1 ? 'Meters' : 'Kilometers');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 130, height: 130,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(130, 130),
                  painter: _MiniRing((totalDistKm * 1000).toInt(), 5000, kGreen)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(displayVal, style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                Text(displayUnit.toUpperCase(), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.35), letterSpacing: 1)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _sideMetric('Real Time', _currentTime, 'Clock', Icons.access_time_rounded, kBlue),
            const SizedBox(height: 14),
            _sideMetric('Calories', '$totalCal', 'Kcal', Icons.local_fire_department_rounded, kCoral),
            const SizedBox(height: 14),
            _sideMetric('Distance', totalDistKm.toStringAsFixed(2), 'Km', Icons.straighten_rounded, kGreen),
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




  String _titleOf(ActivityType t) => t == ActivityType.walking ? 'Walking Activity' : 
                                    t == ActivityType.running ? 'Running Activity' : 
                                    'Cycling Activity';

  Widget _buildActivityChart() {
    final Map<String, double> chartData = {};
    final List<Map<String, dynamic>> trend = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: i)));
      chartData[date] = 0;
    }

    for (var s in _sessions) {
      final dateStr = s['date'].toString().substring(0, 10);
      if (chartData.containsKey(dateStr)) {
        final type = ActivityType.values[(s['type'] as num).toInt()];
        if (type == _selectedType) {
          chartData[dateStr] = chartData[dateStr]! + (s['fit_points'] as num? ?? 0).toDouble();
        }
      }
    }

    chartData.forEach((date, points) {
      trend.add({'date': date, 'points': points});
    });
    trend.sort((a, b) => a['date'].compareTo(b['date']));

    final color = _selectedType == ActivityType.walking ? kTeal : 
                  _selectedType == ActivityType.running ? kCoral : kAmber;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_selectedType?.name.toUpperCase()} PERFORMANCE', 
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const Text('Weekly Points Trend', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('7 DAYS', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _ActivityLinePainter(trend, color)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: trend.map((e) => Text(DateFormat('E').format(DateTime.parse(e['date'])), 
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w700))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> trend;
  final Color color;
  _ActivityLinePainter(this.trend, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    double maxPts = trend.map((e) => (e['points'] as num).toDouble()).fold(100.0, math.max);
    
    final List<Offset> points = [];
    for (int i = 0; i < trend.length; i++) {
      double x = (trend.length > 1) ? (size.width / (trend.length - 1)) * i : size.width / 2;
      double val = (trend[i]['points'] as num).toDouble();
      double y = size.height - (val / maxPts) * size.height * 0.8 - (size.height * 0.1);
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path();
      final fillPath = Path();

      path.moveTo(points[0].dx, points[0].dy);
      fillPath.moveTo(0, size.height);
      fillPath.lineTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
        fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(size.width, size.height);
      fillPath.close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, paint);
      
      canvas.drawCircle(points.last, 6, Paint()..color = color.withOpacity(0.2));
      canvas.drawCircle(points.last, 3, Paint()..color = color);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
