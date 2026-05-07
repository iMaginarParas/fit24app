import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'shell.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'refer_and_earn_page.dart';

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
    
    // Calculate growth percentage if possible
    double growthPct = 0;
    bool isNewGrowth = false;
    if (trend.length >= 2) {
      double last = (trend.last['points'] as num).toDouble();
      double prev = (trend[trend.length - 2]['points'] as num).toDouble();
      if (prev > 0) {
        growthPct = ((last - prev) / prev) * 100;
      } else if (last > 0) {
        isNewGrowth = true;
      }
    }

    return RefreshIndicator(
      onRefresh: _fetchNetwork,
      color: kGreen,
      backgroundColor: const Color(0xFF0B0E11),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Network', 
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2)),
                  const SizedBox(height: 6),
                  Text('Track your direct and indirect team performance.',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(child: _buildReferralSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          SliverToBoxAdapter(child: _buildStatsGrid(summary)),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildAnalyticsCard(trend, growthPct, isNewGrowth),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Direct Referrals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('${levels.isNotEmpty ? (levels[0]['users'] as List).length : 0} People', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w800)),
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
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Indirect Referrals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('${summary['total_users'] - (levels.isNotEmpty ? (levels[0]['users'] as List).length : 0)} People', style: TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w800)),
                ],
              ),
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReferAndEarnPage())),
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
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF13171D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Text('CODE: ', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(_referralCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _referralCode.toUpperCase()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied to clipboard!'), 
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF1C2128),
                    ));
                  },
                  child: Icon(Icons.copy_rounded, color: kGreen.withOpacity(0.7), size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _shareInvite,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: kGreenGrad,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: kGreen.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.black, size: 18),
                  SizedBox(width: 8),
                  Text('Invite', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
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
          _premiumStatCard('Total Network Members', summary['total_users'].toString(), kGreen, Icons.groups_rounded, isFullWidth: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _premiumStatCard('Direct Referrals', fmt.format(summary['direct_points']), kAmber, Icons.person_add_alt_1_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Indirect Referrals', fmt.format(summary['indirect_points']), kBlue, Icons.account_tree_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          _premiumStatCard('Total Network Points', fmt.format(totalPoints), kGreen, Icons.stars_rounded, isFullWidth: true, isGlow: true),
        ],
      ),
    );
  }

  Widget _premiumStatCard(String label, String value, Color color, IconData icon, {bool isFullWidth = false, bool isGlow = false}) => Container(
    padding: EdgeInsets.all(isFullWidth ? 24 : 20),
    width: isFullWidth ? double.infinity : null,
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(0.04)),
      boxShadow: [
        if (isGlow) BoxShadow(color: color.withOpacity(0.05), blurRadius: 40, spreadRadius: -10),
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
      ],
    ),
    child: isFullWidth 
      ? Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08), 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.12)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 0.2)),
                ],
              ),
            ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08), 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.12)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.2), letterSpacing: 0.1)),
          ],
        ),
  );

  Widget _buildAnalyticsCard(List<dynamic> trend, double growthPct, bool isNewGrowth) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.white.withOpacity(0.04)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Growth Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Real-time earnings trend', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            if (growthPct != 0 || isNewGrowth)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (growthPct > 0 || isNewGrowth) ? kGreen.withOpacity(0.1) : kCoral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(isNewGrowth || growthPct > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                      color: (isNewGrowth || growthPct > 0) ? kGreen : kCoral, size: 14),
                    const SizedBox(width: 4),
                    Text(isNewGrowth ? 'NEW GROWTH' : '${growthPct.abs().toStringAsFixed(1)}%', 
                      style: TextStyle(color: (isNewGrowth || growthPct > 0) ? kGreen : kCoral, fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(painter: _SmoothLineChartPainter(trend)),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: trend.isNotEmpty 
            ? trend.map((e) => Text(DateFormat('E').format(DateTime.parse(e['date'])), 
                style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10, fontWeight: FontWeight.w800))).toList()
            : [Text('No data', style: TextStyle(color: Colors.white24, fontSize: 10))],
        ),
      ],
    ),
  );


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
            decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.hub_rounded, color: kBlue, size: 16)),
          ),
          const SizedBox(width: 12),
          Text('Network Level $level', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$count Users', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 12),
          Text('+\$${NumberFormat.compact().format(points)}', style: const TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w800)),
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
    double maxPts = trend.map((e) => (e['points'] as num).toDouble()).fold(100.0, math.max);
    
    final List<Offset> points = [];
    bool allZero = true;
    for (int i = 0; i < trend.length; i++) {
      double x = (trend.length > 1) ? (size.width / (trend.length - 1)) * i : size.width / 2;
      double val = (trend[i]['points'] as num).toDouble();
      if (val > 0) allZero = false;
      double y = size.height - (val / maxPts) * size.height * 0.7 - (size.height * 0.15);
      points.add(Offset(x, y));
    }

    // Draw baseline if all zero
    if (allZero) {
      final baselinePaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.85), baselinePaint);
      
      // Draw a subtle placeholder curve
      final placeholderPath = Path();
      placeholderPath.moveTo(0, size.height * 0.85);
      placeholderPath.quadraticBezierTo(size.width * 0.5, size.height * 0.8, size.width, size.height * 0.85);
      canvas.drawPath(placeholderPath, Paint()..color = kAmber.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    if (points.length > 1 && !allZero) {
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
      
      // Draw all data points with dots
      for (var p in points) {
        canvas.drawCircle(p, 3, Paint()..color = kAmber);
      }

      // Draw end point glow
      canvas.drawCircle(points.last, 6, Paint()..color = kAmber.withOpacity(0.3));
      canvas.drawCircle(points.last, 3.5, Paint()..color = kAmber);
    } else if (points.length == 1 && !allZero) {
      canvas.drawCircle(points[0], 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
