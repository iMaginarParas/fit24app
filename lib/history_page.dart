import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'tracking_service.dart';
import 'session_detail_page.dart';
import 'shell.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  ActivityType? _filter;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final remote = await api.getSessions();
      
      final prefs = await SharedPreferences.getInstance();
      final localList = prefs.getStringList('gps_sessions') ?? [];
      final local = localList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

      if (mounted) {
        setState(() {
          final combined = [...local, ...remote];
          final Map<String, Map<String, dynamic>> unique = {};
          for (var s in combined) {
            final key = s['id']?.toString() ?? s['date'].toString();
            unique[key] = s;
          }
          _sessions = unique.values.toList();
          _sessions.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null 
        ? _sessions 
        : _sessions.where((s) => ActivityType.values[s['type'] as int] == _filter).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ── Background Image (Matches Activity/Home) ───────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/activity_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header (Clean, No notification icon) ───────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Activity History', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                centerTitle: true,
                floating: true,
              ),

              // ── Filter Chips ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _filterChip(null, 'All'),
                        _filterChip(ActivityType.walking, 'Walking'),
                        _filterChip(ActivityType.running, 'Running'),
                        _filterChip(ActivityType.cycling, 'Cycling'),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Activity List ─────────────────────────────────────────────
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kTeal)))
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No activities found', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _sessionCard(filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ActivityType? type, String label) {
    final sel = _filter == type;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? kTeal : kSurface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: sel ? kTeal : kBorder),
          boxShadow: sel ? [BoxShadow(color: kTeal.withOpacity(0.3), blurRadius: 10)] : null,
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.black : Colors.white.withOpacity(0.5),
          fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w600
        )),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final type = ActivityType.values[s['type'] as int];
    final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
    final dur = (s['duration'] as num?)?.toInt() ?? 0;
    final cal = (s['calories'] as num?)?.toInt() ?? 0;
    final date = DateTime.parse(s['date']);
    
    final icon = type == ActivityType.walking ? Icons.directions_walk_rounded :
                 type == ActivityType.running ? Icons.directions_run_rounded :
                 Icons.directions_bike_rounded;
    
    final color = type == ActivityType.walking ? kTeal :
                  type == ActivityType.running ? kCoral : kAmber;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(session: s))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCard.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('EEEE, MMM d').format(date), 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(DateFormat('h:mm a').format(date), 
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _smallMetric(Icons.straighten_rounded, dist < 1000 ? '${dist.toStringAsFixed(0)}m' : '${(dist/1000).toStringAsFixed(2)}km', color),
                      const SizedBox(width: 14),
                      _smallMetric(Icons.access_time_rounded, '${(dur/60).floor()}m ${dur%60}s', color),
                      const SizedBox(width: 14),
                      _smallMetric(Icons.local_fire_department_rounded, '$cal kcal', color),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric(IconData icon, String val, Color color) => Row(
    children: [
      Icon(icon, size: 13, color: color.withOpacity(0.5)),
      const SizedBox(width: 5),
      Text(val, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}
