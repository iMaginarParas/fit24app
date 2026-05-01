import 'package:flutter/material.dart';
import 'auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'shell.dart';
import 'dart:ui' as ui;

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  bool _loading = true;
  List<dynamic> _entries = [];
  String _weekStart = '';
  String _period = 'weekly'; // 'daily' or 'weekly'
  int _offset = 0; // 0 for current, 1 for previous
  late ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController()..addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getLeaderboard(period: _period, offset: _offset);
      if (mounted) {
        setState(() {
          _entries = data['entries'] ?? [];
          _weekStart = data['week_start'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateFilter({String? period, int? offset}) {
    setState(() {
      if (period != null) _period = period;
      if (offset != null) _offset = offset;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ── Premium Mesh Background ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBg, Color(0xFF15191C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kTeal.withOpacity(0.08),
                boxShadow: [BoxShadow(color: kTeal.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          LayoutBuilder(builder: (context, constraints) {
            return RefreshIndicator(
              color: kGreen,
              backgroundColor: const Color(0xFF1A1A1A),
              strokeWidth: 3,
              onRefresh: _loadData,
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: _sc,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                      if (_loading)
                        const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kGreen)))
                      else ...[
                        SliverToBoxAdapter(child: _topThree()),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _listEntry(i + 3),
                              childCount: _entries.length > 3 ? _entries.length - 3 : 0,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 140)),
                      ],
                    ],
                  ),
                  if (!_loading) _stickyMeCard(),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hall of Fame', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
            Text(_period == 'weekly' ? 'WEEKLY CHAMPIONS' : 'DAILY LEADERS', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: kTeal, letterSpacing: 2)),
          ])),
        ]),
        const SizedBox(height: 20),
        Row(
          children: [
            _filterChip(_period == 'weekly' ? 'Weekly' : 'Daily', Icons.calendar_today_rounded, () {
              _updateFilter(period: _period == 'weekly' ? 'daily' : 'weekly');
            }, true),
            const SizedBox(width: 10),
            _filterChip(_offset == 0 ? 'Current' : 'Previous', Icons.history_rounded, () {
              _updateFilter(offset: _offset == 0 ? 1 : 0);
            }, _offset != 0),
          ],
        ),
      ],
    ),
  );

  Widget _filterChip(String label, IconData icon, VoidCallback onTap, bool active) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? kGreen.withOpacity(0.1) : kCard,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: active ? kGreen.withOpacity(0.4) : kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? kGreen : Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? kGreen : Colors.white60)),
        ],
      ),
    ),
  );

  Widget _topThree() {
    if (_entries.length < 3) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _podiumItem(_entries[1], 2, 140, kBlue),
          const SizedBox(width: 16),
          _podiumItem(_entries[0], 1, 170, kAmber),
          const SizedBox(width: 16),
          _podiumItem(_entries[2], 3, 120, kCoral),
        ],
      ),
    );
  }

  Widget _podiumItem(dynamic e, int rank, double h, Color color) {
    final steps = (e['steps'] as num).toInt();
    final uid = e['user_id'] as String;
    final initials = uid.substring(0, 2).toUpperCase();
    final isFirst = rank == 1;
    
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        // Glow Effect
        Container(
          width: isFirst ? 90 : 75, height: isFirst ? 90 : 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 25, spreadRadius: 2)],
          ),
        ),
        AvatarCircle(initials, color, size: isFirst ? 80 : 65),
        Positioned(bottom: 0, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color, 
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
          ),
          child: Text('#$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
        )),
      ]),
      const SizedBox(height: 16),
      Text(NumberFormat.compact().format(steps), style: TextStyle(
        fontSize: isFirst ? 20 : 16, 
        fontWeight: FontWeight.w900, 
        color: Colors.white,
        shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)],
      )),
      const Text('Steps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1)),
      const SizedBox(height: 12),
      // 3D Podium Block
      Container(
        width: 65, height: h - 100, 
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.4), color.withOpacity(0.02)], 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
      ),
    ]);
  }

  Widget _listEntry(int i) {
    final e = _entries[i];
    final rank = i + 1;
    final steps = (e['steps'] as num).toInt();
    final uid = e['user_id'] as String;
    final initials = uid.substring(0, 2).toUpperCase();
    final isMe = uid == ref.read(userIdProvider);

    return GestureDetector(
      onTap: () => _showUserStats(uid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMe ? kGreen.withOpacity(0.08) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isMe ? kGreen.withOpacity(0.4) : Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: Row(children: [
              SizedBox(width: 32, child: Text('$rank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isMe ? kGreen : Colors.white.withOpacity(0.2)))),
              AvatarCircle(initials, isMe ? kGreen : kTeal, size: 44),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isMe ? 'You' : 'Elite Athlete', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('${NumberFormat('#,###').format(steps)} steps', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? kGreen : Colors.white.withOpacity(0.05), 
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isMe ? [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 10)] : null,
                ),
                child: Text('+${e['fit_points']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isMe ? Colors.black : kGreen)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stickyMeCard() {
    final meId = ref.read(userIdProvider);
    final meIdx = _entries.indexWhere((e) => e['user_id'] == meId);
    if (meIdx == -1) return const SizedBox();
    
    final me = _entries[meIdx];
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, kBg.withOpacity(0.9), kBg]),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: kGreenGrad,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Text('${meIdx + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black54)),
            const SizedBox(width: 16),
            const AvatarCircle('ME', Colors.black26, size: 44),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)),
              Text('${NumberFormat('#,###').format(me['steps'])} steps', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
            ])),
            Text('${me['fit_points']} pts', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black)),
          ]),
        ),
      ),
    );
  }

  void _showUserStats(String uid) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => _UserDetailSheet(uid: uid),
    );
  }
}

class _UserDetailSheet extends ConsumerStatefulWidget {
  final String uid;
  const _UserDetailSheet({required this.uid});
  @override
  ConsumerState<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<_UserDetailSheet> {
  bool _loading = true;
  Map<String, dynamic>? _p;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final data = await ref.read(apiServiceProvider).getPublicProfile(widget.uid);
      setState(() { _p = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      child: _loading 
        ? const Center(child: CircularProgressIndicator(color: kGreen))
        : _p == null 
          ? const Center(child: Text('User not found'))
          : Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 30),
              AvatarCircle(_p!['name']?.substring(0, 1).toUpperCase() ?? 'U', kTeal, size: 90),
              const SizedBox(height: 16),
              Text(_p!['name'] ?? 'Fit24 Athlete', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(_p!['city'] ?? 'Active Member', style: TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _miniStat('GOAL', '${_p!['daily_goal']}'),
                _miniStat('RANK', 'Elite'),
                _miniStat('JOINED', '2024'),
              ]),
              const Spacer(),
              _btn('FOLLOW', kTeal, () {
                ref.read(apiServiceProvider).followUser(widget.uid);
                Navigator.pop(context);
              }),
              const SizedBox(height: 20),
            ]),
    );
  }

  Widget _miniStat(String l, String v) => Column(children: [
    Text(l, style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w800, letterSpacing: 1)),
    const SizedBox(height: 4),
    Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
  ]);

  Widget _btn(String t, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black))),
    ),
  );
}
