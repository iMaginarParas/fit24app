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
  int _todaySteps = 0;
  List<dynamic> _challenges = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final t = await api.getTodaySteps();
      final c = await api.getChallenges();
      if (mounted) {
        setState(() {
          _todaySteps = t['steps'] ?? 0;
          _challenges = c;
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
          RefreshIndicator(
            onRefresh: _loadData,
            color: kGreen,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header())),
                if (_loading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kGreen)))
                else if (_challenges.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('No active challenges', style: TextStyle(color: Colors.white38))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final c = _challenges[i];
                          final id = c['id'] as String;
                          final isClaimed = c['is_claimed'] == true;
                          double prog = 0;
                          
                          if (c['requirement_type'] == 'steps') {
                            prog = (_todaySteps / (c['requirement_value'] as num)).clamp(0.0, 1.0);
                          } else if (c['requirement_type'] == 'checkin') {
                            prog = 1.0;
                          }

                          return _challengeCard(
                            id,
                            c['title'], 
                            c['description'], 
                            isClaimed ? _todaySteps : _todaySteps, // Just for display
                            c['requirement_value'] ?? 0, 
                            isClaimed ? Colors.white24 : (prog >= 1.0 ? kGreen : kAmber), 
                            c['requirement_type'] == 'checkin' ? Icons.wb_sunny_rounded : Icons.directions_run_rounded,
                            isClaimed: isClaimed,
                            onClaim: (prog >= 1.0 && !isClaimed) ? () => _claim(id) : null,
                          );
                        },
                        childCount: _challenges.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claim(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      Map<String, dynamic> res;
      if (id == "00000000-0000-0000-0000-000000000001") {
        res = await api.claimDailyCheckIn();
      } else {
        res = await api.claimChallenge(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Reward claimed!'),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
        ));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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

  Widget _challengeCard(String id, String title, String desc, int current, int target, Color color, IconData icon, {bool isClaimed = false, VoidCallback? onClaim}) {
    final prog = (current / target).clamp(0.0, 1.0);
    final isDone = prog >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isClaimed ? Colors.white10 : (isDone ? color.withOpacity(0.4) : kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isClaimed ? Colors.white.withOpacity(0.05) : color.withOpacity(0.12), 
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isClaimed ? Colors.white10 : color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: isClaimed ? Colors.white24 : color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isClaimed ? Colors.white38 : Colors.white)),
            Text(desc, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(isClaimed ? 0.15 : 0.35))),
          ])),
          if (isClaimed) 
            const Icon(Icons.check_circle_rounded, color: Colors.white24, size: 24)
          else if (onClaim != null)
            GestureDetector(
              onTap: onClaim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(8)),
                child: const Text('CLAIM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
              ),
            )
          else if (isDone)
            const Icon(Icons.check_circle_rounded, color: kGreen, size: 24),
        ]),
        const SizedBox(height: 16),
        if (!isClaimed) ...[
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
        ],
      ]),
    );
  }
}
