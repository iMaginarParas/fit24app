import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'shell.dart';

class ChallengesPage extends ConsumerStatefulWidget {
  const ChallengesPage({super.key});

  @override
  ConsumerState<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends ConsumerState<ChallengesPage> {
  bool _loading = true;
  int _today = 0;
  int _weekTotal = 0;
  int _monthTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final t = await api.getTodaySteps();
      final h = await api.getStepHistory(days: 30);
      if (mounted) {
        setState(() {
          _today = t['steps'] ?? 0;
          _weekTotal = h['total_steps'] ?? 0; // History returns sum for requested days
          // Month total calculation from history days
          _monthTotal = h['total_steps'] ?? 0;
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
              'assets/images/challenges_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kGreen)))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _section('Daily Challenges'),
                      _challengeCard('10K Step Sprint', 'Reach 10,000 steps today', _today, 10000, kGreen, Icons.directions_run_rounded),
                      _challengeCard('Early Bird', 'Walk 2,000 steps before noon', _today, 2000, kAmber, Icons.wb_sunny_rounded),
                      
                      const SizedBox(height: 24),
                      _section('Weekly Challenges'),
                      _challengeCard('70K Weekly Warrior', 'Accumulate 70,000 steps this week', _weekTotal, 70000, kPurple, Icons.emoji_events_rounded),
                      _challengeCard('Consistent Mover', 'Sync steps for 5 consecutive days', 4, 5, kBlue, Icons.repeat_rounded),
                      
                      const SizedBox(height: 24),
                      _section('Monthly Goals'),
                      _challengeCard('300K Master', 'Hit 300,000 steps this month', _monthTotal, 300000, kCoral, Icons.workspace_premium_rounded),
                    ]),
                  ),
                ),
            ],
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
      const Text('All Challenges', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(title, style: TextStyle(
        fontSize: 14, color: Colors.white.withOpacity(0.4),
        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
  );

  Widget _challengeCard(String title, String desc, int current, int target, Color color, IconData icon) {
    final prog = (current / target).clamp(0.0, 1.0);
    final done = prog >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: done ? color.withOpacity(0.4) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(desc, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
          ])),
          if (done) const Icon(Icons.check_circle_rounded, color: kGreen, size: 24),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${NumberFormat('#,###').format(current)} / ${NumberFormat('#,###').format(target)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          Text('${(prog * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(100),
          child: Stack(children: [
            Container(height: 8, color: Colors.white.withOpacity(0.05)),
            FractionallySizedBox(widthFactor: prog,
              child: Container(height: 8, decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.6), color]),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
              ))),
          ])),
      ]),
    );
  }
}
