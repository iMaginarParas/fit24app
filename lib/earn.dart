import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shell.dart';

class EarnPage extends StatelessWidget {
  const EarnPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
        SliverToBoxAdapter(child: _balanceCard()),
        SliverToBoxAdapter(child: _rateCards()),
        SliverToBoxAdapter(child: SectionHeader('Active Challenges', action: 'See all')),
        SliverToBoxAdapter(child: _challengesList()),
        SliverToBoxAdapter(child: SectionHeader('Redeem Rewards', action: 'All')),
        SliverToBoxAdapter(child: _redeemRow()),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    ),
  );

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
      Container(
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
    ]),
  );

  Widget _balanceCard() => Padding(
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
              Text('FIT POINTS', style: TextStyle(
                  fontSize: 10, color: Colors.white.withOpacity(0.5),
                  letterSpacing: 2, fontWeight: FontWeight.w700)),
              const Text('12,450', style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.5, height: 1.1)),
            ]),
            const Spacer(),
            // Mini circle stat
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _smallBadge('+5,000', kGreen, 'today'),
              const SizedBox(height: 6),
              _smallBadge('+850', kAmber, 'bonus'),
            ]),
          ]),
          const SizedBox(height: 20),
          // Progress
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Next milestone: 15,000 pts', style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
            const Text('83%', style: TextStyle(
                fontSize: 11, color: kGreen, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(children: [
              Container(height: 8, color: Colors.white.withOpacity(0.08)),
              FractionallySizedBox(widthFactor: 0.83,
                child: Container(height: 8, decoration: BoxDecoration(
                  gradient: kGreenGrad,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.6), blurRadius: 8)],
                ))),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _actionBtn('Withdraw', Icons.arrow_upward_rounded, kGreen)),
            const SizedBox(width: 10),
            Expanded(child: _actionBtn('Share', Icons.share_rounded, kBlue)),
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

  Widget _actionBtn(String l, IconData icon, Color c) => Container(
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
  );

  Widget _rateCards() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Expanded(child: _rateTile('Per Step', '5 pts', kGreen, Icons.directions_walk_rounded)),
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

  Widget _challengesList() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(children: [
      _challengeCard('10K Step Sprint', 'Complete 10,000 steps today',
          0.72, '+50,000 pts', kGreen, Icons.directions_run_rounded, '2h left'),
      const SizedBox(height: 10),
      _challengeCard('Weekly Warrior', '70,000 steps this week',
          0.41, '+200,000 pts', kPurple, Icons.emoji_events_rounded, '4d left'),
      const SizedBox(height: 10),
      _challengeCard('Early Bird', '2,000 steps before 9am',
          0.0, '+15,000 pts', kAmber, Icons.wb_sunny_rounded, 'Tomorrow'),
    ]),
  );

  Widget _challengeCard(String title, String desc, double prog,
      String reward, Color color, IconData icon, String timeLeft) =>
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
        _redeemCard('☕', 'Coffee', '10,000', kAmber),
        _redeemCard('🎮', 'Game Credits', '25,000', kPurple),
        _redeemCard('💸', 'Cash Out', '50,000', kGreen),
        _redeemCard('🎁', 'Gift Card', '40,000', kCoral),
        _redeemCard('👟', 'Shoes', '100,000', kBlue),
      ],
    ),
  );

  Widget _redeemCard(String icon, String title, String cost, Color color) =>
    Container(
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
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('$cost pts', style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ]),
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