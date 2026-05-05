import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell.dart';
import 'points_provider.dart';
import 'notifications_provider.dart';

class SpinWheelPage extends ConsumerStatefulWidget {
  const SpinWheelPage({super.key});

  @override
  ConsumerState<SpinWheelPage> createState() => _SpinWheelPageState();
}

class _SpinWheelPageState extends ConsumerState<SpinWheelPage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _spinning = false;
  bool _hasSpunToday = false;

  final List<SpinSlot> _slots = [
    SpinSlot('50 FIT24', 50, kBlue),
    SpinSlot('60 FIT24', 60, kPink),
    SpinSlot('70 FIT24', 70, kTeal),
    SpinSlot('Try Again', 0, kBorder),
    SpinSlot('80 FIT24', 80, kAmber),
    SpinSlot('100 FIT24', 100, kGreen),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _checkSpunToday();
  }

  Future<void> _checkSpunToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpin = prefs.getString('last_spin_date');
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (lastSpin == today) {
      if (mounted) setState(() => _hasSpunToday = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_spinning || _hasSpunToday) return;

    setState(() => _spinning = true);

    // Randomize winning slot
    final rand = math.Random();
    final winIndex = rand.nextInt(_slots.length);
    
    // Calculate rotation
    final sliceAngle = 2 * math.pi / _slots.length;
    // Base rotation to land on index 0
    // Then subtract angle to land on winIndex
    // Add multiple full rotations
    final targetAngle = (10 * 2 * math.pi) - (winIndex * sliceAngle) - (sliceAngle / 2);

    _anim = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCirc)
    );

    _ctrl.reset();
    await _ctrl.forward();

    final wonSlot = _slots[winIndex];

    if (mounted) {
      _showResultDialog(wonSlot);
      setState(() {
        _spinning = false;
        _hasSpunToday = true;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_spin_date', DateTime.now().toIso8601String().split('T')[0]);

    if (wonSlot.points > 0) {
      ref.read(userPointsProvider.notifier).updateLocal(wonSlot.points);
      
      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Lucky Spin! 🎡',
        message: 'You won ${wonSlot.points} FIT24 points from the daily spin.',
        points: '+${wonSlot.points}',
        icon: Icons.auto_awesome_rounded,
        color: kAmber,
      );
    }
  }

  void _showResultDialog(SpinSlot slot) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Text(slot.points > 0 ? 'YOU WON!' : 'AW, SNAP!', 
          style: TextStyle(
            color: slot.points > 0 ? kAmber : Colors.white, 
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slot.points > 0 ? kAmber.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              ),
              child: Icon(slot.points > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                color: slot.points > 0 ? kAmber : Colors.white54, size: 64),
            ),
            const SizedBox(height: 24),
            Text(slot.points > 0 
                ? 'Congratulations! You just won ${slot.points} FIT24 points!'
                : 'Better luck next time. Come back tomorrow for another spin!',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: slot.points > 0 ? kGreenGrad : null,
                    color: slot.points > 0 ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(slot.points > 0 ? 'CLAIM POINTS' : 'GOT IT', 
                      style: TextStyle(
                        color: slot.points > 0 ? Colors.black : Colors.white, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        title: const Text('Spin & Win', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // Background decorations
          Positioned.fill(
            child: Image.asset(
              'assets/images/earn_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
          Positioned(
            top: -50, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: kPurple.withOpacity(0.15),
                boxShadow: [BoxShadow(color: kPurple.withOpacity(0.15), blurRadius: 100)],
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: kTeal.withOpacity(0.15),
                boxShadow: [BoxShadow(color: kTeal.withOpacity(0.15), blurRadius: 100)],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Text('Daily Spin', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: 2
                )),
                const SizedBox(height: 8),
                const Text('Spin & Win', style: TextStyle(
                  fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5, height: 1.1
                )),
                const SizedBox(height: 12),
                Text('Spin the wheel every day for a chance\nto win up to 100 FIT24 points!', 
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), height: 1.5, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                
                // The Wheel
                Center(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCard,
                          gradient: RadialGradient(
                            colors: [kCard.withOpacity(0.5), kCard],
                            stops: const [0.8, 1.0],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 8),
                          boxShadow: [
                            BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 40, spreadRadius: 5),
                            BoxShadow(color: kTeal.withOpacity(0.1), blurRadius: 80, spreadRadius: -10),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ctrl,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _ctrl.isAnimating || _ctrl.isCompleted ? _anim.value : 0,
                                  child: SizedBox(
                                    width: 280, height: 280,
                                    child: CustomPaint(
                                      painter: WheelPainter(_slots),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Static Logo in center
                            Container(
                              width: 60, height: 60,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)
                                ],
                              ),
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                          ],
                        ),
                      ),
                      // Pointer
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 16, spreadRadius: 2),
                            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.arrow_drop_down_circle_rounded, color: Colors.white, size: 54),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Spin Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: GestureDetector(
                    onTap: _spin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: _hasSpunToday ? null : kGreenGrad,
                        color: _hasSpunToday ? Colors.white.withOpacity(0.05) : null,
                        borderRadius: BorderRadius.circular(24),
                        border: _hasSpunToday ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                        boxShadow: _hasSpunToday ? [] : [
                          BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _hasSpunToday ? 'COME BACK TOMORROW' : (_spinning ? 'SPINNING...' : 'SPIN NOW'), 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w900, 
                            color: _hasSpunToday ? Colors.white.withOpacity(0.4) : Colors.black,
                            letterSpacing: 1,
                          )
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasSpunToday)
                  Text('You have already used your spin for today.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpinSlot {
  final String label;
  final int points;
  final Color color;
  SpinSlot(this.label, this.points, this.color);
}

class WheelPainter extends CustomPainter {
  final List<SpinSlot> slots;
  WheelPainter(this.slots);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final sliceAngle = 2 * math.pi / slots.length;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < slots.length; i++) {
      final startAngle = i * sliceAngle - math.pi / 2;
      
      // Professional Gradient Slices
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            slots[i].color.withOpacity(0.6), 
            slots[i].color,
            slots[i].color.withOpacity(0.8),
          ],
          stops: const [0.0, 0.7, 1.0],
          center: Alignment.center,
          radius: 1.2,
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(rect, startAngle, sliceAngle, true, paint);

      // Inner shadow/depth for slices
      final innerShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(rect, startAngle, sliceAngle, true, innerShadowPaint);

      // Draw polished borders
      final borderPaint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(rect, startAngle, sliceAngle, true, borderPaint);

      // Draw Text with better typography feel
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sliceAngle + sliceAngle / 2 - math.pi / 2);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: slots[i].label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95), 
            fontWeight: FontWeight.w900, 
            fontSize: 14,
            letterSpacing: 1.0,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(1, 1)),
              Shadow(color: slots[i].color.withOpacity(0.5), blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.48, -textPainter.height / 2));
      
      canvas.restore();
    }
    
    // Outer professional ring
    final outerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, outerRingPaint);

    // Center area depth (Glassmorphism / Neon feel)
    final centerPaint = Paint()..color = const Color(0xFF0F1216);
    canvas.drawCircle(center, radius * 0.24, centerPaint);
    
    final glowPaint = Paint()
      ..color = kGreen.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 0.24, glowPaint);

    final centerBorderPaint = Paint()
      ..shader = LinearGradient(
        colors: [kGreen.withOpacity(0.8), kTeal.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.24, centerBorderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
