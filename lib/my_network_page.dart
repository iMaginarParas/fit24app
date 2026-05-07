import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'shell.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class MyNetworkPage extends ConsumerStatefulWidget {
  const MyNetworkPage({super.key});

  @override
  ConsumerState<MyNetworkPage> createState() => _MyNetworkPageState();
}

class _MyNetworkPageState extends ConsumerState<MyNetworkPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _networkData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNetwork();
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
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBg, Color(0xFF1A1F25)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                expandedHeight: 80,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: kBg.withOpacity(0.5)),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('My Network', 
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                centerTitle: true,
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: kTeal)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(child: Text('Error: $_error', style: const TextStyle(color: kCoral))),
                )
              else ...[
                // Summary Section
                SliverToBoxAdapter(
                  child: _buildSummary(_networkData!['summary']),
                ),

                // Levels Section
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final levels = _networkData!['levels'] as List;
                        if (index >= levels.length) return null;
                        return _LevelExpansionTile(levelData: levels[index]);
                      },
                      childCount: (_networkData!['levels'] as List).length,
                    ),
                  ),
                ),
                
                if ((_networkData!['levels'] as List).isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text('No network yet', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('Invite friends to start earning!', style: TextStyle(color: Colors.white24, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> summary) {
    final fmt = NumberFormat.compact();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Direct Points', 
                  fmt.format(summary['direct_points']), 
                  kAmber, 
                  Icons.stars_rounded
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _statCard(
                  'Indirect Points', 
                  fmt.format(summary['indirect_points']), 
                  kTeal, 
                  Icons.account_tree_rounded
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statCard(
            'Total Network Users', 
            summary['total_users'].toString(), 
            kBlue, 
            Icons.people_alt_rounded,
            isWide: true
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon, {bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: isWide ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          if (isWide)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            )
        ],
      ),
    );
  }
}

class _LevelExpansionTile extends StatefulWidget {
  final Map<String, dynamic> levelData;
  const _LevelExpansionTile({required this.levelData});

  @override
  State<_LevelExpansionTile> createState() => _LevelExpansionTileState();
}

class _LevelExpansionTileState extends State<_LevelExpansionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final level = widget.levelData['level'];
    final count = widget.levelData['count'];
    final points = widget.levelData['points_earned'];
    final users = widget.levelData['users'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _isExpanded ? kTeal.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (val) => setState(() => _isExpanded = val),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (level == 1 ? kAmber : kTeal).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('L$level', style: TextStyle(color: level == 1 ? kAmber : kTeal, fontWeight: FontWeight.w900)),
            ),
          ),
          title: Text(level == 1 ? 'Direct Affiliate' : 'Level $level', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Text('$count Users • +${NumberFormat.compact().format(points)} Points', 
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: Colors.white24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: users.map((u) => _buildUserTile(u)).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final name = user['name'] ?? 'New User';
    final city = user['city'] ?? 'Earth';
    final avatar = user['avatar_url'];
    final joinedAt = DateTime.parse(user['joined_at']);
    final dateStr = DateFormat('MMM d, y').format(joinedAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: AvatarCircle(
        name.substring(0, 1).toUpperCase(), 
        kTeal, 
        size: 40,
        imagePath: avatar,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text('$city • $dateStr', style: TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.verified_user_rounded, color: kGreen, size: 16),
    );
  }
}
