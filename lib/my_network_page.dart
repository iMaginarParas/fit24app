import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'shell.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

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
      if (mounted) setState(() => _referralCode = p['referral_code'] ?? 'FIT24USER');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E11), // Deep Fintech Black
      body: Stack(
        children: [
          // Ambient Background Glows
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

          // Back Button
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

    return RefreshIndicator(
      onRefresh: _fetchNetwork,
      color: kTeal,
      backgroundColor: const Color(0xFF13171D),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          
          // Header Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Referral Network', 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: kAmber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('FIT PRO', style: TextStyle(color: kAmber, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Invite friends. Earn forever. Get points from up to 10 levels of your network.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          // Referral Link Section
          SliverToBoxAdapter(child: _buildReferralSection()),

          // Stats Grid
          SliverToBoxAdapter(child: _buildStatsGrid(summary)),

          // Earnings Graph & Network Visualization Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildEarningsChart(summary)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildNetworkMap(levels)),
                ],
              ),
            ),
          ),

          // Top Referrals (Level 1 - Direct)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Level 1 (Direct)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('View All', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final l1 = levels.isNotEmpty ? levels[0] : null;
                  if (l1 == null) return null;
                  final users = l1['users'] as List;
                  if (index >= users.length) return null;
                  return _buildReferralRow(users[index]);
                },
                childCount: levels.isNotEmpty ? (levels[0]['users'] as List).length : 0,
              ),
            ),
          ),

          // Other Levels (2-10)
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
                  if (index == 0) return const SizedBox(); // Skip level 1 in the list if already shown
                  if (index >= levels.length) return null;
                  return _buildLevelDepthTile(levels[index]);
                },
                childCount: levels.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

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
                Text(_referralCode, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                  },
                  child: const Icon(Icons.copy_rounded, color: kTeal, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
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
      ],
    ),
  );

  Widget _buildStatsGrid(Map<String, dynamic> summary) {
    final fmt = NumberFormat.compact();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _premiumStatCard('Total Referrals', summary['total_users'].toString(), kAmber, Icons.people_outline_rounded, '+12 this week')),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Active Users', (summary['total_users'] * 0.8).toInt().toString(), kTeal, Icons.flash_on_rounded, '80% of total')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _premiumStatCard('Total Earned', fmt.format(summary['direct_points'] + summary['indirect_points']), kGreen, Icons.account_balance_wallet_outlined, '+${fmt.format(2400)} this week')),
              const SizedBox(width: 16),
              Expanded(child: _premiumStatCard('Max Level', 'Level 10', kBlue, Icons.military_tech_rounded, 'Earn up to 10%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumStatCard(String label, String value, Color color, IconData icon, String delta) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF13171D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            Text(delta, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3))),
      ],
    ),
  );

  Widget _buildEarningsChart(Map<String, dynamic> summary) => Container(
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Earnings Overview', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Points growth over time', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Text('This Week', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 14),
              ]),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 100,
          width: double.infinity,
          child: CustomPaint(painter: _SmoothLineChartPainter()),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['13 May', '15 May', '17 May', '19 May'].map((d) => Text(d, style: TextStyle(color: Colors.white24, fontSize: 9))).toList(),
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
        const Text('Network Map', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
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
          _mapNode('You', Colors.white, isMe: true),
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
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900))),
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
              Text('+2,400 pts', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w900)),
              Text('Active', style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.bold)),
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
  @override
  void paint(Canvas canvas, Size size) {
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

    // Smoother curve points
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.1),
    ];

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

    // Draw dot at the end
    canvas.drawCircle(points.last, 4, Paint()..color = kAmber);
    canvas.drawCircle(points.last, 8, Paint()..color = kAmber.withOpacity(0.2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
