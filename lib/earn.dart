import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'challenges_page.dart';
import 'rewards_page.dart';
import 'shell.dart';
import 'points_provider.dart';
import 'step_provider.dart';
import 'activity.dart';

class EarnPage extends ConsumerStatefulWidget {
  const EarnPage({super.key});
  @override
  ConsumerState<EarnPage> createState() => _EP();
}

class _EP extends ConsumerState<EarnPage> {
  bool _loading = true;
  int _todayPoints = 0;
  int _totalPoints = 0;
  int _todaySteps = 0;
  List<dynamic> _todaySessions = [];
  List<dynamic> _challenges = [];
  late ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController()..addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await ref.read(userPointsProvider.notifier).refresh();
      final t = await api.getTodaySteps();
      final h = await api.getStepHistory(days: 7);
      final s = await api.getSessions();
      final c = await api.getChallenges();
      
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final todaySessions = s.where((sess) {
        final createdAt = sess['created_at'] as String?;
        return createdAt != null && createdAt.startsWith(todayStr);
      }).toList();

      if (mounted) {
        setState(() {
          _todayPoints = t['fit_points'] ?? 0;
          _todaySteps = t['steps'] ?? 0;
          _totalPoints = h['total_fit_points'] ?? 0;
          _todaySessions = todaySessions;
          _challenges = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = ref.watch(userPointsProvider);
    final liveSteps = ref.watch(liveStepProvider).valueOrNull ?? _todaySteps;
    // Calculate display points: Total points from backend + unsynced live steps
    final displayPoints = totalPoints + math.max(0, liveSteps - _todaySteps).toInt();
    
    return Scaffold(
      backgroundColor: kBg,
      body: RefreshIndicator(
        color: kGreen,
        backgroundColor: const Color(0xFF111111),
        strokeWidth: 3,
        displacement: 40,
        onRefresh: _loadData,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/earn_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
            CustomScrollView(
              controller: _sc,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                SliverToBoxAdapter(child: _balanceCard(displayPoints, liveSteps)),
                SliverToBoxAdapter(child: _rateCards()),
                SliverToBoxAdapter(child: SectionHeader('Today\'s Activity')),
                SliverToBoxAdapter(child: _activityBreakdown(liveSteps)),
                SliverToBoxAdapter(child: SectionHeader('Active Challenges', action: 'See all', onAction: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesPage()));
                })),
                SliverToBoxAdapter(child: _challengesList(liveSteps)),
                SliverToBoxAdapter(child: SectionHeader('Redeem Rewards', action: 'All', onAction: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()));
                })),
                SliverToBoxAdapter(child: _redeemRow()),
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
        Text('Your Wallet', style: TextStyle(
            fontSize: 12, color: Colors.white.withOpacity(0.35))),
        const Text('Earn', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityPage())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            Icon(Icons.history_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text('History', style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]),
  );

  Widget _balanceCard(int points, int liveSteps) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            kGreen.withOpacity(0.25),
            kTeal.withOpacity(0.12),
            kCard,
          ],
          stops: const [0, 0.4, 1],
        ),
        border: Border.all(color: kGreen.withOpacity(0.3)),
        boxShadow: [BoxShadow(
            color: kGreen.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        // Hex bg
        Positioned.fill(child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: CustomPaint(painter: _HexBg()),
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGreenGrad,
                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 16)],
              ),
              child: const Center(child: Text('⚡', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text('FIT24', style: TextStyle(
                  fontSize: 10, color: Colors.white.withOpacity(0.5),
                  letterSpacing: 2, fontWeight: FontWeight.w700)),
              Text(NumberFormat('#,###').format(points), style: const TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.5, height: 1.1)),
            ]),
            const Spacer(),
            // Mini circle stat
             Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _smallBadge('+${NumberFormat('#,###').format(liveSteps)}', kGreen, 'today'),
              const SizedBox(height: 6),
              _smallBadge('+0', kAmber, 'bonus'),
            ]),
          ]),
          const SizedBox(height: 20),
          // Progress
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Next milestone: 15,000 pts', style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
            Text('${((points / 15000).clamp(0.0, 1.0) * 100).toInt()}%', style: const TextStyle(
                fontSize: 11, color: kGreen, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(children: [
              Container(height: 8, color: Colors.white.withOpacity(0.08)),
              FractionallySizedBox(widthFactor: (points / 15000).clamp(0.0, 1.0),
                child: Container(height: 8, decoration: BoxDecoration(
                  gradient: kGreenGrad,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.6), blurRadius: 8)],
                ))),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _actionBtn('Withdraw', Icons.arrow_upward_rounded, kGreen, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()));
            })),
          ]),
        ]),
      ]),
    ),
  );

  Widget _smallBadge(String val, Color color, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(val, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.35))),
  ]);

  Widget _actionBtn(String l, IconData icon, Color c, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 7),
        Text(l, style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _rateCards() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Expanded(child: _rateTile('Per Step', '1 pt', kGreen, Icons.directions_walk_rounded)),
      const SizedBox(width: 10),
      Expanded(child: _rateTile('Goal Bonus', '+50K', kAmber, Icons.flag_rounded)),
      const SizedBox(width: 10),
      Expanded(child: _rateTile('7-Day Streak', '+100K', kPurple, Icons.local_fire_department_rounded)),
    ]),
  );

  Widget _rateTile(String label, String value, Color color, IconData icon) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.35))),
      ]),
    );

  Widget _activityBreakdown(int currentSteps) {
    // Calculate points from sessions
    int sessionPoints = 0;
    for (var s in _todaySessions) {
      sessionPoints += (s['steps'] as num?)?.toInt() ?? 0;
    }

    // Calculate points from completed challenges (mocked logic based on current UI)
    int challengePoints = 0;
    if (currentSteps >= 10000) challengePoints += 50000;
    // Weekly and Early Bird might be harder to check without more state, 
    // but let's assume they are 0 for now unless we have logic for them.

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            _breakdownRow('Steps', currentSteps, kGreen, Icons.directions_walk_rounded),
            _divider(),
            _breakdownRow('Activity', sessionPoints, kBlue, Icons.fitness_center_rounded),
            _divider(),
            _breakdownRow('Challenges', challengePoints, kAmber, Icons.emoji_events_rounded),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, int points, Color color, IconData icon) => Row(
    children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 14),
      Text(label, style: TextStyle(
          fontSize: 15, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
      const Spacer(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${NumberFormat('#,###').format(points)} pts', style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('today', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
        ],
      ),
    ],
  );

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: Colors.white.withOpacity(0.03), height: 1),
  );

   Widget _challengesList(int currentSteps) {
    if (_challenges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)),
          child: const Center(child: Text('No active challenges', style: TextStyle(color: Colors.white38))),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: _challenges.map((c) {
        double prog = 0;
        if (c['requirement_type'] == 'steps') {
          prog = (currentSteps / (c['requirement_value'] as num)).clamp(0.0, 1.0);
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _challengeCard(
            c['id'],
            c['title'], 
            c['description'],
            prog, 
            '+${c['reward_coins']} pts', 
            kGreen, 
            Icons.directions_run_rounded, 
            'Active',
            onClaim: prog >= 1.0 ? () => _claim(c['id']) : null,
          ),
        );
      }).toList()),
    );
  }

  Future<void> _claim(String id) async {
    try {
      final res = await ref.read(apiServiceProvider).claimChallenge(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Reward claimed!'),
          backgroundColor: kGreen,
        ));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _challengeCard(String id, String title, String desc, double prog,
      String reward, Color color, IconData icon, String timeLeft, {VoidCallback? onClaim}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.35))),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (onClaim != null)
              GestureDetector(
                onTap: onClaim,
                child: Chip24('CLAIM', color: kGreen),
              )
            else
              Chip24(reward, color: color),
            const SizedBox(height: 5),
            Text(timeLeft, style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(0.3))),
          ]),
        ]),
        if (prog > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(100),
            child: Stack(children: [
              Container(height: 6, color: Colors.white.withOpacity(0.05)),
              FractionallySizedBox(widthFactor: prog,
                child: Container(height: 6, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.6), color]),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
                ))),
            ])),
          const SizedBox(height: 5),
          Text('${(prog * 100).toInt()}% complete',
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
        ],
      ]),
    );

  Widget _redeemRow() => SizedBox(
    height: 148,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _redeemCard('assets/images/reward_coffee.png', 'Coffee', '10,000', kAmber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
        _redeemCard('assets/images/reward_gaming.png', 'Game Credits', '25,000', kPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
        _redeemCard('assets/images/reward_cash.png', 'Cash Out', '50,000', kGreen, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
        _redeemCard('assets/images/reward_gift.png', 'Gift Card', '40,000', kCoral, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
        _redeemCard('assets/images/reward_shoes.png', 'Shoes', '100,000', kBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
      ],
    ),
  );

  Widget _redeemCard(String imagePath, String title, String cost, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130, margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 16)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('$cost pts', style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
}

class _HexBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.stroke..strokeWidth = 0.8;
    const s = 22.0;
    for (double y = 0; y < size.height + s; y += s * 1.5) {
      for (double x = 0; x < size.width + s; x += s * math.sqrt(3)) {
        _hex(canvas, Offset(x, y), s, p);
        _hex(canvas, Offset(x + s * math.sqrt(3) / 2, y + s * 0.75), s, p);
      }
    }
  }
  void _hex(Canvas c, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close(); c.drawPath(path, p);
  }
  @override bool shouldRepaint(_) => false;
}
