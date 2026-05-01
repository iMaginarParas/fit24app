import 'package:flutter/material.dart';
import 'shell.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Help Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader('Common Questions'),
          _faqItem('How are Fit Points calculated?', 'You earn 1 Fit Point for every step you take. Bonus points are awarded for tracked workout sessions like running or cycling.'),
          _faqItem('How do I sync my steps?', 'Fit24 automatically syncs with Health Connect. If your steps aren\'t updating, ensure you have granted all permissions in the Profile > Health Connect settings.'),
          _faqItem('Can I use Fit24 without GPS?', 'Yes! Background step counting works using your phone\'s motion sensors. GPS is only required for precise tracking of Running or Cycling sessions.'),
          _faqItem('How do I redeem rewards?', 'Once you have enough Fit Points, go to the Earn tab and select a reward to redeem. We will send the voucher to your registered phone number.'),
          
          const SizedBox(height: 48),
          const Center(
            child: Text('Version 1.2.4', style: TextStyle(color: Colors.white24, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(title.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
  );

  Widget _faqItem(String q, String a) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Text(a, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.4)),
      ],
    ),
  );
}
