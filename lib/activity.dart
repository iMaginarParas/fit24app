import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shell.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _AP();
}

class _AP extends State<ActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _period = 0; // 0=Today 1=Week 2=Month

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (mounted) setState(() => _period = _tab.index); });
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  static const _weekSteps = [8200, 12400, 6800, 15000, 9300, 4600, 7136];
  static const _days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  static const _colors = [kPurple, kBlue, kTeal, kAmber, kCoral, kPurple, kGreen];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
          SliverToBoxAdapter(child: _periodTabs()),
          SliverToBoxAdapter(child: _mainStepCard()),
          SliverToBoxAdapter(child: _healthRow()),
          SliverToBoxAdapter(child: SectionHeader('Daily Breakdown')),
          SliverToBoxAdapter(child: _barChart()),
          SliverToBoxAdapter(child: SectionHeader('Activity Log')),
          SliverToBoxAdapter(child: _logList()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
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
        Row(children: [
          const Text('Running Activity', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.5), size: 22),
        ]),
      ]),
      const Spacer(),
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

  Widget _mainStepCard() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        // Left: step ring
        SizedBox(
          width: 130, height: 130,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(130, 130),
                painter: _MiniRing(7136, 10000, kGreen)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('7,136', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Steps', style: TextStyle(
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
          _sideMetric('Calories', '928', 'Kcal', Icons.local_fire_department_rounded, kCoral),
          const SizedBox(height: 14),
          _sideMetric('Training', '125', 'Minutes', Icons.fitness_center_rounded, kGreen),
        ])),
      ]),
    ),
  );

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
        'Heart Rate', '96 BPM', Icons.favorite_rounded, kCoral,
        widget: _miniHeartChart())),
      const SizedBox(width: 12),
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

  Widget _miniHeartChart() => SizedBox(height: 40,
    child: CustomPaint(size: const Size(double.infinity, 40),
        painter: _MiniHeartPainter()));

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
    final max = _weekSteps.reduce(math.max);
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
            children: List.generate(7, (i) {
              final frac = _weekSteps[i] / max;
              final h = math.max(8.0, 94 * frac);
              final isToday = i == 6;
              final color = _colors[i];
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end, children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 50),
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isToday ? null : color.withOpacity(0.5),
                      gradient: isToday ? kGreenGrad : null,
                      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(_days[i][0], style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday ? kGreen : Colors.white.withOpacity(0.35))),
                ]),
              ));
            }),
          ),
        ),
      ),
    );
  }

  Widget _logList() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        _logCard('Today', '7,136 steps', '5.0 km • 356 cal • 43 min', kGreen, Icons.directions_run_rounded, true),
        const SizedBox(height: 10),
        _logCard('Yesterday', '4,600 steps', '3.2 km • 230 cal • 28 min', kBlue, Icons.directions_walk_rounded, false),
        const SizedBox(height: 10),
        _logCard('Apr 12', '9,300 steps', '6.5 km • 465 cal • 56 min', kCoral, Icons.directions_run_rounded, false),
        const SizedBox(height: 10),
        _logCard('Apr 11', '15,000 steps', '10.5 km • 750 cal • 90 min', kAmber, Icons.emoji_events_rounded, false),
      ],
    ),
  );

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

class _MiniHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.15, size.height * 0.6),
      Offset(size.width * 0.22, size.height * 0.1),
      Offset(size.width * 0.28, size.height * 0.95),
      Offset(size.width * 0.35, size.height * 0.5),
      Offset(size.width * 0.55, size.height * 0.55),
      Offset(size.width * 0.62, size.height * 0.1),
      Offset(size.width * 0.68, size.height * 0.95),
      Offset(size.width * 0.75, size.height * 0.5),
      Offset(size.width, size.height * 0.55),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final cp = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      path.quadraticBezierTo(cp.dx, cp.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = kCoral
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    final fill = Path.from(path)..lineTo(size.width, size.height)
      ..lineTo(0, size.height)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [kCoral.withOpacity(0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }
  @override bool shouldRepaint(_) => false;
}