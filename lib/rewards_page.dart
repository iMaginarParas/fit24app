import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'shell.dart';
import 'points_provider.dart';

class RewardItem {
  final String title;
  final int points;
  final String image;
  final String category;
  final Color color;

  RewardItem({
    required this.title,
    required this.points,
    required this.image,
    required this.category,
    required this.color,
  });
}

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
    RewardItem(
      title: 'FIT24 Energy Drink',
      points: 100000,
      image: 'assets/images/energy_drink.png',
      category: 'Lifestyle',
      color: kGreen,
    ),
    RewardItem(
      title: 'Foam Roller Pro',
      points: 120000,
      image: 'assets/images/foam_roller.png',
      category: 'Recovery',
      color: kGreen,
    ),
    RewardItem(
      title: 'Yoga Mat Premium',
      points: 150000,
      image: 'assets/images/yoga_mat.png',
      category: 'Wellness',
      color: kPink,
    ),
    RewardItem(
      title: 'Smart Bottle',
      points: 200000,
      image: 'assets/images/smart_bottle.png',
      category: 'Hydration',
      color: kTeal,
    ),
    RewardItem(
      title: 'FIT24 Official Kit',
      points: 250000,
      image: 'assets/images/fit24_kit.png',
      category: 'Merchandise',
      color: kGreen,
    ),
    RewardItem(
      title: 'Sports Earbuds',
      points: 400000,
      image: 'assets/images/sports_earbuds.png',
      category: 'Audio',
      color: kCoral,
    ),
    RewardItem(
      title: 'Smart Fitness Bands',
      points: 500000,
      image: 'assets/images/fitness_band.png',
      category: 'Tech',
      color: kTeal,
    ),
    RewardItem(
      title: 'Pro Running Shoes',
      points: 600000,
      image: 'assets/images/running_shoes.png',
      category: 'Fitness',
      color: kBlue,
    ),
    RewardItem(
      title: 'Massage Gun Pro',
      points: 800000,
      image: 'assets/images/massage_gun.png',
      category: 'Recovery',
      color: kPurple,
    ),
    RewardItem(
      title: 'Adjustable Dumbbells',
      points: 1200000,
      image: 'assets/images/adjustable_dumbbells.png',
      category: 'Equipment',
      color: kAmber,
    ),
  ];

  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tech', 'Fitness', 'Recovery', 'Merchandise', 'Lifestyle'];

  @override
  Widget build(BuildContext context) {
    final totalPoints = ref.watch(userPointsProvider);
    final filteredRewards = _selectedCategory == 'All' 
        ? _rewards 
        : _rewards.where((r) => r.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kGreen.withOpacity(0.05),
              ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              _buildAppBar(totalPoints),
              _buildCategoryFilter(),
              _buildRewardsGrid(filteredRewards, totalPoints),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(int points) => SliverAppBar(
    expandedHeight: 180,
    pinned: true,
    backgroundColor: kBg,
    elevation: 0,
    leadingWidth: 70,
    leading: Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    ),
    flexibleSpace: FlexibleSpaceBar(
      background: Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Redeem', style: TextStyle(
                      fontSize: 14, color: kGreen, fontWeight: FontWeight.w900, letterSpacing: 2
                    )),
                    const Text('Rewards', style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1
                    )),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kAmber.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: kAmber.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(NumberFormat('#,###').format(points), style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCategoryFilter() => SliverToBoxAdapter(
    child: SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final sel = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? kGreen : kSurface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: sel ? kGreen : Colors.white.withOpacity(0.05)),
                    boxShadow: sel ? [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 12)] : null,
                  ),
                  child: Text(cat, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: sel ? Colors.black : Colors.white60
                  )),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildRewardsGrid(List<RewardItem> items, int userPoints) => SliverPadding(
    padding: const EdgeInsets.all(20),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _rewardCard(items[i], userPoints),
        childCount: items.length,
      ),
    ),
  );

  Widget _rewardCard(RewardItem item, int userPoints) {
    final canAfford = userPoints >= item.points;
    
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background gradient glow
            Positioned(
              top: -20, right: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withOpacity(0.08),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Container
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Hero(
                        tag: item.title,
                        child: Image.asset(item.image, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category Tag
                  Text(item.category.toUpperCase(), style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w900, color: item.color, letterSpacing: 1
                  )),
                  const SizedBox(height: 4),
                  
                  // Title
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  
                  // Points & Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${NumberFormat('#,###').format(item.points)}', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                          const Text('POINTS', style: TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Redemption coming soon in the next update!'),
                            backgroundColor: kTeal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Text('COMING SOON', style: TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 0.5
                          )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRedeem(RewardItem item, bool canAfford) {
    if (!canAfford) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Insufficient points for ${item.title}'),
        backgroundColor: kCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset(item.image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            Text('Redeem ${item.title}?', style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white
            )),
            const SizedBox(height: 8),
            Text('This will deduct ${NumberFormat('#,###').format(item.points)} points from your wallet.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 32),
            GreenBtn('CONFIRM REDEMPTION', onTap: () {
              Navigator.pop(ctx);
              _showSuccess();
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: kGreen.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 80, color: kGreen),
                const SizedBox(height: 24),
                const Text('ORDER PLACED!', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white
                )),
                const SizedBox(height: 12),
                const Text('Our team will contact you for shipping details within 24 hours.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54)),
                const SizedBox(height: 32),
                GreenBtn('GOT IT', onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
