import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'shell.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';

class MyNetworkPage extends ConsumerStatefulWidget {
  const MyNetworkPage({super.key});

  @override
  ConsumerState<MyNetworkPage> createState() => _MyNetworkPageState();
}

class _MyNetworkPageState extends ConsumerState<MyNetworkPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _networkData;
  String? _error;
  String _referralCode = '';

  @override
  void initState() {
    super.initState();
    _fetchNetwork();
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    final api = ref.read(apiServiceProvider);
    try {
      final p = await api.getProfile();
      if (mounted) setState(() => _referralCode = p['referral_code'] ?? '');
    } catch (_) {}
  }

  Future<void> _fetchNetwork() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getNetwork();
      if (mounted) {
        setState(() {
          _networkData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _shareInvite() {
    if (_referralCode.isEmpty) return;
    final message = 'Join me on Fit24! Use my referral code: ${_referralCode.toUpperCase()} to get started. Download now: https://fit24.app';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -50,
            child: _glow(kTeal.withOpacity(0.08), 300),
          ),
          Positioned(
            bottom: 100, left: -100,
            child: _glow(kPurple.withOpacity(0.05), 400),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kTeal))
          else if (_error != null)
            Center(child: Text('Error: $_error', style: const TextStyle(color: kCoral)))
          else
            _buildDashboard(context),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)],
    ),
  );

  Widget _buildDashboard(BuildContext context) {
    final summary = _networkData!['summary'];
    final levels = _networkData!['levels'] as List;
    final trend = summary['earnings_trend'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchNetwork,
      color: kTeal,
      backgroundColor: const Color(0xFF13171D),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Referral Network', 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('Invite friends. Earn forever. Get points from up to 10 levels of your network.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: _buildReferralSection()),

          SliverToBoxAdapter(child: _buildStatsGrid(summary)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildEarningsChart(trend)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildNetworkMap(levels)),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Level 1 (Direct)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('${levels.isNotEmpty ? (levels[0]['users'] as List).length : 0} Members', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: levels.isNotEmpty && (levels[0]['users'] as List).isNotEmpty 
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final users = levels[0]['users'] as List;
                      if (index >= users.length) return null;
                      return _buildReferralRow(users[index]);
                    },
                    childCount: (levels[0]['users'] as List).length,
                  ),
                )
              : SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.group_add_rounded, color: Colors.white.withOpacity(0.1), size: 48),
                        const SizedBox(height: 16),
                        const Text('No Referrals Yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Start sharing your code to see your network grow here.', 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
              child: Text('Network Depth (Levels 2-10)', 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) return const SizedBox();
                  if (index >= levels.length) return null;
                  return _buildLevelDepthTile(levels[index]);
                },
                childCount: levels.length,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStrategyCard(context),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [kTeal.withOpacity(0.15), kBlue.withOpacity(0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: kTeal.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: kTeal, size: 20),
            SizedBox(width: 10),
            Text('Pro Growth Tip', style: TextStyle(color: kTeal, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Build a Deep Network', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('While Level 1 earns you 10,000 points instantly, your true wealth comes from depth. Help your Level 1 referrals invite others to unlock recurring points from Level 2-10.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferAndEarnPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(
              child: Text('Get More Referrals', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildReferralSection() => Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF13171D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Text('Code: ', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(_referralCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _referralCode.toUpperCase()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!'), behavior: SnackBarBehavior.floating));
                  },
                  child: const Icon(Icons.copy_rounded, color: kTeal, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _shareInvite,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: kGreenGrad,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: const Row(
              children: [
                Icon(Icons.share_rounded, color: Colors.black, size: 18),
                SizedBox(width: 8),
                Text('Invite Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildStatsGrid(Map<String, dynamic> summary) {
    final fmt = NumberFormat.compact();
    final totalPoints = summary['total_points'] ?? (summary['direct_points'] + summary['indirect_points']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _premiumStatCard('Total Referrals', summary['total_users'].toString(), kAmber, Icons.people_outline_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Network Points', fmt.format(totalPoints), kGreen, Icons.stars_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _premiumStatCard('Direct (L1)', fmt.format(summary['direct_points']), kTeal, Icons.person_add_alt_1_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Indirect (L2-10)', fmt.format(summary['indirect_points']), kBlue, Icons.account_tree_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumStatCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3))),
      ],
    ),
  );

  Widget _buildEarningsChart(List<dynamic> trend) => Container(
    height: 220,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Growth Trend', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        const Text('Daily referral points (Last 7 days)', style: TextStyle(color: Colors.white24, fontSize: 10)),
        const Spacer(),
        SizedBox(
          height: 100,
          width: double.infinity,
          child: CustomPaint(painter: _SmoothLineChartPainter(trend)),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: trend.isNotEmpty 
            ? trend.map((e) => Text(DateFormat('d MMM').format(DateTime.parse(e['date'])), style: TextStyle(color: Colors.white24, fontSize: 8))).toList()
            : [Text('No data', style: TextStyle(color: Colors.white24, fontSize: 8))],
        ),
      ],
    ),
  );

  Widget _buildNetworkMap(List<dynamic> levels) => Container(
    height: 220,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Structure', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Expanded(child: _buildMapVisual(levels)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Size', style: TextStyle(color: Colors.white24, fontSize: 10)),
            Text('${_networkData!['summary']['total_users']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    ),
  );

  Widget _buildMapVisual(List<dynamic> levels) {
    int l1 = levels.isNotEmpty ? levels[0]['count'] : 0;
    int l2 = levels.length > 1 ? levels[1]['count'] : 0;
    int l3 = levels.length > 2 ? levels[2]['count'] : 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mapNode('YOU', Colors.white, isMe: true),
          _connector(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _mapNode('$l1', kAmber, sub: 'L1'),
              _mapNode('$l2', kTeal, sub: 'L2'),
              _mapNode('$l3', kBlue, sub: 'L3'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapNode(String label, Color color, {bool isMe = false, String? sub}) => Column(
    children: [
      Container(
        width: isMe ? 40 : 34, height: isMe ? 40 : 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(isMe ? 1 : 0.4), width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900))),
      ),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w700)),
      ]
    ],
  );

  Widget _connector() => Container(width: 1.5, height: 20, color: Colors.white.withOpacity(0.05));

  Widget _buildReferralRow(Map<String, dynamic> user) {
    final name = user['name'] ?? 'Fit24 Athlete';
    final joinedAtStr = user['joined_at'] ?? DateTime.now().toIso8601String();
    final joinedAt = DateTime.parse(joinedAtStr);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13171D).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          AvatarCircle(name.substring(0, 1), kTeal, size: 36, imagePath: user['avatar_url']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(DateFormat('MMM d, y').format(joinedAt), style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+10k pts', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w900)),
              Text('DIRECT', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDepthTile(Map<String, dynamic> levelData) {
    final level = levelData['level'];
    final count = levelData['count'];
    final points = levelData['points_earned'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('L$level', style: const TextStyle(color: kTeal, fontWeight: FontWeight.w900, fontSize: 11))),
          ),
          const SizedBox(width: 12),
          Text('Level $level Network', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$count Users', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 12),
          Text('+${NumberFormat.compact().format(points)}', style: const TextStyle(color: kTeal, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SmoothLineChartPainter extends CustomPainter {
  final List<dynamic> trend;
  _SmoothLineChartPainter(this.trend);

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    final paint = Paint()
      ..color = kAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [kAmber.withOpacity(0.3), kAmber.withOpacity(0)],
      )
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Map trend to points
    double maxPts = trend.map((e) => (e['points'] as num).toDouble()).reduce(math.max);
    if (maxPts == 0) maxPts = 10000; // Default scale

    final List<Offset> points = [];
    for (int i = 0; i < trend.length; i++) {
      double x = (size.width / (trend.length - 1)) * i;
      double y = size.height - ((trend[i]['points'] as num).toDouble() / maxPts) * size.height * 0.8;
      // Clamp y to prevent overflow but keep it inside
      y = y.clamp(size.height * 0.1, size.height * 0.9);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    canvas.drawCircle(points.last, 4, Paint()..color = kAmber);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
