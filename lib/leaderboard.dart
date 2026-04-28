import 'package:flutter/material.dart';
import 'auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'shell.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  bool _loading = true;
  List<dynamic> _entries = [];
  String _weekStart = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getLeaderboard();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/leaderboard_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          RefreshIndicator(
            color: kGreen,
            backgroundColor: const Color(0xFF1A1A1A),
            strokeWidth: 3,
            onRefresh: _loadData,
            child: CustomScrollView(
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
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
        ),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Leaderboard', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('Week of $_weekStart', style: TextStyle(
            fontSize: 12, color: Colors.white.withOpacity(0.4))),
      ]),
    ]),
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
    final steps = e['steps'] as int;
    final uid = e['user_id'] as String;
    final initials = uid.substring(0, 2).toUpperCase();
    
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        AvatarCircle(initials, color, size: rank == 1 ? 70 : 60),
        Positioned(bottom: 0, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('#$rank', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
        )),
      ]),
      const SizedBox(height: 12),
      Text(NumberFormat.compact().format(steps), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      const Text('Steps', style: TextStyle(fontSize: 10, color: Colors.white38)),
      const SizedBox(height: 10),
      Container(width: 60, height: h - 100, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.05)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      )),
    ]);
  }

  Widget _listEntry(int i) {
    final e = _entries[i];
    final rank = i + 1;
    final steps = e['steps'] as int;
    final uid = e['user_id'] as String;
    final initials = uid.substring(0, 2).toUpperCase();
    final isMe = uid == ref.read(userIdProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? kGreen.withOpacity(0.1) : kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isMe ? kGreen.withOpacity(0.3) : kBorder),
      ),
      child: Row(children: [
        SizedBox(width: 30, child: Text('$rank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.3)))),
        AvatarCircle(initials, kGreen, size: 40),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? 'You' : 'User ${uid.substring(0, 4)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('${NumberFormat('#,###').format(steps)} steps', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(100)),
          child: Text('+${e['fit_points']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kGreen)),
        ),
      ]),
    );
  }
}
