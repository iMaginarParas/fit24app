import 'package:flutter/material.dart';
import 'shell.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/rewards_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SafeArea(bottom: false, child: _header(context))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildListDelegate([
                    _rewardCard('Starbucks Coffee', '10,000', kAmber, 'assets/images/reward_coffee.png'),
                    _rewardCard('Game Credits', '25,000', kPurple, 'assets/images/reward_gaming.png'),
                    _rewardCard('PayPal Cashout', '50,000', kGreen, 'assets/images/reward_cash.png'),
                    _rewardCard('Amazon Gift Card', '40,000', kCoral, 'assets/images/reward_gift.png'),
                    _rewardCard('Nike Air Max', '120,000', kBlue, 'assets/images/reward_shoes.png'),
                    _rewardCard('Apple Music 3mo', '15,000', kCoral, 'assets/images/reward_gift.png'),
                    _rewardCard('Spotify Premium', '12,000', kGreen, 'assets/images/reward_gift.png'),
                    _rewardCard('Gym Shark Outfit', '85,000', kPurple, 'assets/images/reward_shoes.png'),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
      const Text('Redeem Rewards', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _rewardCard(String title, String cost, Color color, String img) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 80, width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withOpacity(0.1),
            image: DecorationImage(image: AssetImage(img), fit: BoxFit.cover),
          ),
        ),
        const Spacer(),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.bolt_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text('$cost pts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(child: Text('Redeem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
        ),
      ]),
    );
  }
}
