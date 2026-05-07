import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'shell.dart';
import 'points_provider.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final TextEditingController _pointsController = TextEditingController();
  int _selectedMethod = 0; // 0: PayPal, 1: Bank, 2: Crypto

  // Assume conversion rate: 1,000 points = ₹0 (Disabled)
  static const double _conversionRate = 0.0;

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  void _withdraw() {
    final pointsStr = _pointsController.text.replaceAll(',', '');
    final pointsToWithdraw = int.tryParse(pointsStr) ?? 0;
    final userPoints = ref.read(userPointsProvider);

    if (pointsToWithdraw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount to withdraw')));
      return;
    }
    if (pointsToWithdraw > userPoints) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient points balance')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Withdrawal request for ₹${(pointsToWithdraw * _conversionRate).toStringAsFixed(2)} submitted!'),
        backgroundColor: kGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final userPoints = ref.watch(userPointsProvider);
    final inputPoints = int.tryParse(_pointsController.text.replaceAll(',', '')) ?? 0;
    final cashAmount = inputPoints * _conversionRate;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/earn_bg.png', // Reuse earn_bg for consistent look
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _balanceCard(userPoints),
                        const SizedBox(height: 30),
                        const Text('Exchange Amount', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 16),
                        _inputSection(userPoints),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'You will receive: ₹${cashAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900, color: kGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text('Withdrawal Method', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 16),
                        _methodsSection(),
                        const SizedBox(height: 40),
                        _withdrawButton(userPoints, inputPoints),
                        const SizedBox(height: 40),
                      ],
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

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
      const Text('Withdraw Cash', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _balanceCard(int points) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [kGreen.withOpacity(0.2), kCard, kCard],
      ),
      border: Border.all(color: kGreen.withOpacity(0.3)),
      boxShadow: [BoxShadow(color: kGreen.withOpacity(0.1), blurRadius: 20)],
    ),
    child: Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kGreen.withOpacity(0.15),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 10)],
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, color: kGreen, size: 26),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance', style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${NumberFormat('#,###').format(points)} pts', style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
            Text('≈ ₹${(points * _conversionRate).toStringAsFixed(2)} INR', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kGreen)),
          ],
        ),
      ],
    ),
  );

  Widget _inputSection(int userPoints) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: kGreen, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  setState(() {});
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _pointsController.text = userPoints.toString();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('MAX', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: kGreen)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: Colors.white.withOpacity(0.05), height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rate: 1,000 pts = ₹0', style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.5))),
            Text('Min: 5,000 pts', style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      ],
    ),
  );

  Widget _methodsSection() => Row(
    children: [
      Expanded(child: _methodCard(0, 'PayPal', Icons.paypal_rounded, kBlue)),
      const SizedBox(width: 12),
      Expanded(child: _methodCard(1, 'Bank', Icons.account_balance_rounded, kPurple)),
      const SizedBox(width: 12),
      Expanded(child: _methodCard(2, 'Crypto', Icons.currency_bitcoin_rounded, kAmber)),
    ],
  );

  Widget _methodCard(int index, String title, IconData icon, Color color) {
    final isSelected = _selectedMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : kBorder),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white.withOpacity(0.4), size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.white.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _withdrawButton(int userPoints, int inputPoints) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Text('COMING SOON', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
      ),
    );
  }
}
