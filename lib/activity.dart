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
  ActivityType? _selectedType;
  int? _selIdx;
  late ScrollController _sc;
  int _chartIdx = 0;
  final PageController _pc = PageController();

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
            CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                SliverToBoxAdapter(child: _periodTabs()),
                SliverToBoxAdapter(child: _mainStepCard(liveSteps)),
                SliverToBoxAdapter(child: SectionHeader('Activity Totals')),
                SliverToBoxAdapter(child: _modeTotals()),
                SliverToBoxAdapter(child: SectionHeader('Daily Breakdown')),
                SliverToBoxAdapter(child: _barChart(liveSteps)),
                SliverToBoxAdapter(child: SectionHeader('Activity Log')),
                SliverToBoxAdapter(child: _logList(liveSteps)),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
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
            const PopupMenuItem(value: null, child: Text('All Activities')),
            const PopupMenuItem(value: ActivityType.walking, child: Text('Walking')),
            const PopupMenuItem(value: ActivityType.running, child: Text('Running')),
            const PopupMenuItem(value: ActivityType.cycling, child: Text('Cycling')),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_selectedType == null ? 'All Activities' : _titleOf(_selectedType!), style: const TextStyle(
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
    double walkDist = 0, walkDur = 0, runDist = 0, runDur = 0, cycleDist = 0, cycleDur = 0;

    for (var s in _sessions) {
      final type = ActivityType.values[(s['type'] as num).toInt()];
      final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
      final dur = (s['duration'] as num?)?.toInt() ?? 0;
      if (type == ActivityType.walking) { walkDist += dist; walkDur += dur; }
      else if (type == ActivityType.running) { runDist += dist; runDur += dur; }
      else if (type == ActivityType.cycling) { cycleDist += dist; cycleDur += dur; }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _modeCard('WALK', walkDist, walkDur.toInt(), Icons.directions_walk_rounded, kTeal),
        const SizedBox(width: 12),
        _modeCard('RUN', runDist, runDur.toInt(), Icons.directions_run_rounded, kCoral),
        const SizedBox(width: 12),
        _modeCard('CYCLE', cycleDist, cycleDur.toInt(), Icons.directions_bike_rounded, kAmber),
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
    final filtered = _selectedType == null 
        ? _sessions 
        : _sessions.where((s) => ActivityType.values[(s['type'] as num).toInt()] == _selectedType).toList();
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
          final type = ActivityType.values[(s['type'] as num).toInt()];
          final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
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

  Widget _mainStepCard(int liveSteps) {
    final todayLog = _history.isNotEmpty ? _history.first : null;
    final dailySteps = todayLog != null ? (todayLog['steps'] as num?)?.toInt() ?? 0 : 0;
    
    int filteredSteps = 0;
    double filteredDist = 0;
    int filteredCal = 0;
    
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    for (var s in _sessions) {
      if (s['date'].startsWith(todayStr)) {
        final type = ActivityType.values[s['type'] as int];
        if (_selectedType == null || _selectedType == type) {
          filteredSteps += (s['steps'] as num?)?.toInt() ?? 0;
          filteredDist += (s['distance'] as num?)?.toDouble() ?? 0.0;
          filteredCal += (s['calories'] as num?)?.toInt() ?? 0;
        }
      }
    }

    if (_selectedType == null || _selectedType == ActivityType.walking) {
      final bestSteps = math.max(dailySteps, liveSteps);
      filteredSteps += bestSteps;
      filteredDist += (bestSteps * 0.75); // meters
      filteredCal += (bestSteps ~/ 20);
    }

    final totalTodaySteps = filteredSteps;
    double totalDistKm = filteredDist / 1000.0;
    int totalCal = filteredCal;
    
    final isStepBased = _selectedType == null || _selectedType == ActivityType.walking;
    final displayVal = isStepBased 
        ? NumberFormat('#,###').format(totalTodaySteps)
        : (totalDistKm < 1 ? '${(totalDistKm * 1000).toStringAsFixed(0)}' : '${totalDistKm.toStringAsFixed(2)}');
    final displayUnit = isStepBased ? 'Steps' : (totalDistKm < 1 ? 'Meters' : 'Kilometers');

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
                  painter: _MiniRing(isStepBased ? totalTodaySteps : (totalDistKm * 1000).toInt(), isStepBased ? 10000 : 5000, kGreen)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(displayVal, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(displayUnit, style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.4))),
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

  Widget _barChart(int liveSteps) {
    return Column(
      children: [
        SizedBox(
          height: 310,
          child: PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _chartIdx = i),
            children: [
              _metricChartSlide(
                'Steps', 
                liveSteps, 
                (d) => (d['steps'] as num?)?.toInt() ?? 0, 
                kGreen, 
                'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600',
                'Steps'
              ),
              _metricChartSlide(
                'Calories', 
                liveSteps, 
                (d) => ((d['steps'] as num?)?.toInt() ?? 0) ~/ 20, 
                kCoral, 
                'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=600',
                'Kcal'
              ),
              _metricChartSlide(
                'Distance', 
                liveSteps, 
                (d) => (((d['steps'] as num?)?.toInt() ?? 0) * 0.75) / 1000.0, 
                kBlue, 
                'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?q=80&w=600',
                'Km',
                isKm: true
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => _chartDot(i == _chartIdx)),
        ),
      ],
    );
  }

  Widget _chartDot(bool active) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    width: active ? 18 : 6, height: 6,
    decoration: BoxDecoration(
      color: active ? kGreen : Colors.white24,
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Widget _metricChartSlide(String title, int liveSteps, dynamic Function(dynamic) valFn, Color color, String img, String unit, {bool isKm = false}) {
    // Generate a stable 7-day window
    final now = DateTime.now();
    final List<Map<String, dynamic>> chartData = [];
    double totalAll = 0;
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final histEntry = _history.firstWhere(
        (h) => h['log_date'] == dateStr, 
        orElse: () => {'log_date': dateStr, 'steps': 0}
      );
      
      double totalVal = 0;
      if (_selectedType == null || _selectedType == ActivityType.walking) {
        double s = valFn(histEntry).toDouble();
        if (i == 0) {
          if (title == 'Steps') {
            s = math.max(s, liveSteps.toDouble());
          } else if (title == 'Calories') {
            s = math.max(s, (liveSteps ~/ 20).toDouble());
          } else if (title == 'Distance') {
            s = math.max(s, (liveSteps * 0.75) / 1000.0);
          }
        }
        totalVal += s;
      }
      
      for (var s in _sessions) {
        if (s['date'].startsWith(dateStr)) {
          final type = ActivityType.values[s['type'] as int];
          if (_selectedType == null || _selectedType == type) {
            final sessSteps = (s['steps'] as num?)?.toInt() ?? 0;
            final sessDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
            if (title == 'Steps') totalVal += sessSteps;
            else if (title == 'Calories') totalVal += (s['calories'] as num?)?.toInt() ?? 0;
            else if (title == 'Distance') totalVal += sessDist / 1000.0;
          }
        }
      }
      
      totalAll += totalVal;
      chartData.add({'date': dateStr, 'val': totalVal});
    }

    final avg = totalAll / chartData.length;
    final maxVal = chartData.map((d) => d['val'] as double).fold(0.0, (m, v) => math.max(m, v));
    final chartMax = math.max(isKm ? 5.0 : 5000.0, maxVal * 1.2);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorder),
          image: DecorationImage(
            image: NetworkImage(img),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.darken),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(isKm ? '${totalAll.toStringAsFixed(1)} km' : '${totalAll.round()} total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Text('Avg: ${isKm ? avg.toStringAsFixed(1) : avg.round()} ${isKm ? "km" : "steps"}/day',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                  ]),
                ]),
                Icon(Icons.insights_rounded, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(chartData.length, (i) {
                  final d = chartData[i];
                  final v = d['val'] as double;
                  final frac = v / chartMax;
                  final h = math.max(6.0, 130 * frac);
                  final date = DateTime.parse(d['date']);
                  final isToday = i == chartData.length - 1;
                  
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _selIdx = (_selIdx == i ? null : i)),
                      behavior: HitTestBehavior.opaque,
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (_selIdx == i || (v > 0 && isToday))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(4)),
                              child: Text(isKm ? v.toStringAsFixed(1) : (v > 1000 ? '${(v/1000).toStringAsFixed(1)}k' : v.round().toString()), 
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isToday ? color : Colors.white)),
                            ),
                          )
                        else
                          const SizedBox(height: 17),
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(height: 130, width: 12, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(100))),
                            AnimatedContainer(
                              duration: Duration(milliseconds: 600 + i * 50),
                              curve: Curves.easeOutQuart,
                              height: h.toDouble(),
                              width: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                boxShadow: v > 0 ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(DateFormat('E').format(date).substring(0, 1), style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                            color: isToday ? color : Colors.white.withOpacity(0.3))),
                      ]),
                    ),
                  ));
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logList(int liveSteps) {
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, color: Colors.white.withOpacity(0.05), size: 40),
              const SizedBox(height: 12),
              Text('No activities recorded yet', 
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _history.map((d) {
          final date = DateTime.parse(d['log_date']);
          final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
          int steps = (d['steps'] as num?)?.toInt() ?? 0;
          if (isToday) steps = math.max(steps, liveSteps);
          
          final cal = (steps ~/ 20); // Simplified for log
          final dist = (steps * 0.75) / 1000.0;
          
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
