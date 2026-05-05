import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'shell.dart';

class ReferAndEarnPage extends ConsumerStatefulWidget {
  const ReferAndEarnPage({super.key});

  @override
  ConsumerState<ReferAndEarnPage> createState() => _ReferAndEarnPageState();
}

class _ReferAndEarnPageState extends ConsumerState<ReferAndEarnPage> {
  String _referralCode = 'LOADING...';

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (forceRefresh) {
      try {
        final api = ref.read(apiServiceProvider);
        final profile = await api.getProfile();
        await prefs.setString('profile_data', jsonEncode(profile));
      } catch (e) {
        debugPrint('Failed to refresh profile: $e');
      }
    }

    final dataStr = prefs.getString('profile_data');
    if (dataStr != null) {
      final map = jsonDecode(dataStr);
      final code = map['referral_code'];
      
      if (code == null && !forceRefresh) {
        // Try one refresh if code is null
        await _loadCode(forceRefresh: true);
        return;
      }

      setState(() {
        _referralCode = (code as String? ?? 'N/A').toUpperCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = [
      {'level': 'Direct affiliate sponsor', 'points': '10,000', 'color': kAmber, 'icon': Icons.star_rounded},
      {'level': 'Level 1', 'points': '1,000', 'color': kTeal, 'icon': Icons.people_rounded},
      {'level': 'Level 2', 'points': '1,000', 'color': kTeal, 'icon': Icons.people_outline_rounded},
      {'level': 'Level 3', 'points': '1,000', 'color': kBlue, 'icon': Icons.group_add_rounded},
      {'level': 'Level 4', 'points': '1,000', 'color': kBlue, 'icon': Icons.group_rounded},
      {'level': 'Level 5', 'points': '1,000', 'color': kPink, 'icon': Icons.share_rounded},
      {'level': 'Level 6', 'points': '1,000', 'color': kPink, 'icon': Icons.share_rounded},
      {'level': 'Level 7', 'points': '1,000', 'color': kPurple, 'icon': Icons.connect_without_contact_rounded},
      {'level': 'Level 8', 'points': '1,000', 'color': kPurple, 'icon': Icons.connect_without_contact_rounded},
      {'level': 'Level 9', 'points': '1,000', 'color': kGreen, 'icon': Icons.diversity_3_rounded},
      {'level': 'Level 10', 'points': '1,000', 'color': kGreen, 'icon': Icons.diversity_3_rounded},
    ];

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
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAmber.withOpacity(0.05),
                boxShadow: [BoxShadow(color: kAmber.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
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
                title: const Text('Refer & Earn', 
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                centerTitle: true,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: kAmber.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: kAmber.withOpacity(0.2), blurRadius: 30)],
                        ),
                        child: const Icon(Icons.volunteer_activism_rounded, size: 64, color: kAmber),
                      ),
                      const SizedBox(height: 24),
                      const Text('Invite Friends, Earn Big!', 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text('Share your referral code to build your network and earn massive Fit24 points.', 
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Referral Code Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.4), letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                if (_referralCode == 'N/A' || _referralCode == 'LOADING...')
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() => _referralCode = 'GENERATING...');
                                      await _loadCode(forceRefresh: true);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: kAmber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: kAmber.withOpacity(0.5)),
                                      ),
                                      child: const Text('GENERATE CODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kAmber)),
                                    ),
                                  )
                                else
                                  Text(_referralCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kGreen, letterSpacing: 2)),
                              ],
                            ),
                            if (_referralCode != 'N/A' && _referralCode != 'LOADING...' && _referralCode != 'GENERATING...')
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _referralCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Referral code copied!'), backgroundColor: kGreen, behavior: SnackBarBehavior.floating),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: kGreen.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.copy_rounded, color: kGreen, size: 20),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      GreenBtn('Share with Friends', onTap: () {
                        // TODO: Implement actual sharing via Share plugin if needed
                        Clipboard.setData(ClipboardData(text: 'Join me on Fit24! Use my referral code: $_referralCode'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite text copied!'), backgroundColor: kGreen, behavior: SnackBarBehavior.floating),
                        );
                      }),
                      
                      const SizedBox(height: 48),
                      Row(
                        children: [
                          const Icon(Icons.account_tree_rounded, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          Text('NETWORK REWARDS', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.4), letterSpacing: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = levels[index];
                      final color = item['color'] as Color;
                      final isTop = index == 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isTop ? 16 : 12),
                        decoration: BoxDecoration(
                          color: isTop ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isTop ? color.withOpacity(0.3) : Colors.white.withOpacity(0.06),
                            width: isTop ? 1.5 : 1
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isTop ? 40 : 32,
                              height: isTop ? 40 : 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item['icon'] as IconData, color: color, size: isTop ? 20 : 16),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['level'] as String, style: TextStyle(
                                    fontSize: isTop ? 15 : 13, 
                                    fontWeight: isTop ? FontWeight.w900 : FontWeight.w700, 
                                    color: Colors.white.withOpacity(isTop ? 1.0 : 0.9)
                                  )),
                                  if (isTop) ...[
                                    const SizedBox(height: 2),
                                    Text('Primary referral bonus', style: TextStyle(
                                      fontSize: 10, color: Colors.white.withOpacity(0.4))),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+${item['points']}', style: TextStyle(
                                  fontSize: isTop ? 16 : 14, fontWeight: FontWeight.w900, color: color)),
                                Text('FIT24', style: TextStyle(
                                  fontSize: 8, fontWeight: FontWeight.w800, color: color.withOpacity(0.6))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: levels.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}
