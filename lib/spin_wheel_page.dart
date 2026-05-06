import 'dart:async';
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
  Duration? _timeLeft;
  Timer? _countdownTimer;

  final List<SpinSlot> _slots = [
    SpinSlot('50 PTS', 50, kBlue, Icons.fitness_center_rounded),
    SpinSlot('60 PTS', 60, kPink, Icons.directions_run_rounded),
    SpinSlot('70 PTS', 70, kTeal, Icons.bolt_rounded),
    SpinSlot('TRY AGAIN', 0, kBorder, Icons.sentiment_dissatisfied_rounded),
    SpinSlot('80 PTS', 80, kAmber, Icons.timer_rounded),
    SpinSlot('100 PTS', 100, kGreen, Icons.emoji_events_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _checkSpinAvailability();
  }

  void _checkSpinAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinTs = prefs.getInt('last_spin_timestamp');
    
    if (lastSpinTs != null) {
      final lastSpin = DateTime.fromMillisecondsSinceEpoch(lastSpinTs);
      final now = DateTime.now();
      final diff = now.difference(lastSpin);
      
      if (diff.inHours < 24) {
        if (mounted) {
          setState(() {
            _hasSpunToday = true;
            _timeLeft = const Duration(hours: 24) - diff;
          });
          _startCountdown();
        }
      } else {
        if (mounted) setState(() => _hasSpunToday = false);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft == null || _timeLeft!.inSeconds <= 0) {
          _hasSpunToday = false;
          _timeLeft = null;
          timer.cancel();
        } else {
          _timeLeft = _timeLeft! - const Duration(seconds: 1);
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    String h = d.inHours.toString().padLeft(2, '0');
    String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _countdownTimer?.cancel();
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
    await prefs.setInt('last_spin_timestamp', DateTime.now().millisecondsSinceEpoch);
    _timeLeft = const Duration(hours: 24);
    _startCountdown();

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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slot.points > 0 ? slot.color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                border: Border.all(color: slot.points > 0 ? slot.color.withOpacity(0.3) : Colors.white10, width: 2),
                boxShadow: [
                  if (slot.points > 0) BoxShadow(color: slot.color.withOpacity(0.2), blurRadius: 20)
                ],
              ),
              child: Icon(slot.icon, color: slot.points > 0 ? slot.color : Colors.white54, size: 64),
            ),
            const SizedBox(height: 24),
            Text(slot.points > 0 
                ? 'Congratulations! You just won ${slot.points} FIT24 points!'
                : 'Better luck next time. Come back tomorrow for another spin!',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
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
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Luck of the Day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
        centerTitle: true,
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
          // Animated Glow Orbs
          Positioned(
            top: 100, left: -50,
            child: _GlowOrb(color: kGreen.withOpacity(0.15), size: 300),
          ),
          Positioned(
            bottom: 50, right: -100,
            child: _GlowOrb(color: kTeal.withOpacity(0.15), size: 400),
          ),
          
          // Confetti Layer
          if (_ctrl.isCompleted && !_spinning)
            Positioned.fill(child: IgnorePointer(child: _ConfettiEffect())),
          
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
                          gradient: SweepGradient(
                            colors: [
                              kGreen.withOpacity(0.1),
                              kTeal.withOpacity(0.1),
                              kPurple.withOpacity(0.1),
                              kGreen.withOpacity(0.1),
                            ],
                            stops: const [0, 0.33, 0.66, 1],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 10),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10),
                            BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 60, spreadRadius: -5),
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
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 64),
                            Positioned(
                              top: 4,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                              ),
                            ),
                          ],
                        ),
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
                          _hasSpunToday 
                            ? (_timeLeft != null ? 'NEXT SPIN IN ${_formatDuration(_timeLeft!)}' : 'COME BACK TOMORROW') 
                            : (_spinning ? 'SPINNING...' : 'SPIN NOW'), 
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
                if (_hasSpunToday && _timeLeft != null)
                  Text('Your next free spin will be available in ${_formatDuration(_timeLeft!)}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
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
  final IconData icon;
  SpinSlot(this.label, this.points, this.color, this.icon);
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
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sliceAngle, true, borderPaint);

      // Draw Icon (The "Image" part)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sliceAngle + sliceAngle / 2 - math.pi / 2);
      
      // Icon rendering
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(slots[i].icon.codePoint),
          style: TextStyle(
            fontSize: 28,
            fontFamily: slots[i].icon.fontFamily,
            package: slots[i].icon.fontPackage,
            color: Colors.white.withOpacity(0.9),
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
              Shadow(color: slots[i].color.withOpacity(0.8), blurRadius: 20),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      // Position text closer to center
      iconPainter.paint(canvas, Offset(radius * 0.65, -iconPainter.height / 2));

      // Draw Text with professional typography
      final textPainter = TextPainter(
        text: TextSpan(
          text: slots[i].label,
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.w900, 
            fontSize: 9, 
            height: 1.1,
            letterSpacing: 0.2,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(1, 1)),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: radius * 0.5);
      // Position text closer to center
      textPainter.paint(canvas, Offset(radius * 0.25, -textPainter.height / 2));
      
      canvas.restore();
    }
    
    // Outer LED Ticks
    final tickPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 48; i++) {
      final angle = (i * 2 * math.pi / 48) - math.pi / 2;
      final isSlotTick = i % (48 ~/ slots.length) == 0;
      
      tickPaint.color = isSlotTick ? kGreen : Colors.white.withOpacity(0.2);
      final tickRadius = isSlotTick ? 3.0 : 1.5;
      
      final x = center.dx + (radius + 12) * math.cos(angle);
      final y = center.dy + (radius + 12) * math.sin(angle);
      
      if (isSlotTick) {
        canvas.drawCircle(Offset(x, y), tickRadius + 2, Paint()..color = kGreen.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      canvas.drawCircle(Offset(x, y), tickRadius, tickPaint);
    }

    // Outer professional ring
    final outerRingPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.white.withOpacity(0.01), Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.01)],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 20))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius + 20, outerRingPaint);

    // Center area depth (Glassmorphism / Neon feel)
    final centerPaint = Paint()..color = const Color(0xFF0F1216);
    canvas.drawCircle(center, radius * 0.24, centerPaint);
    
    final glowPaint = Paint()
      ..color = kGreen.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 0.24, glowPaint);

    // Center border with inner shadow
    final centerBorderPaint = Paint()
      ..shader = LinearGradient(
        colors: [kGreen, kTeal, kBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius * 0.24, centerBorderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 4)],
      ),
    );
  }
}

class _ConfettiEffect extends StatefulWidget {
  @override
  State<_ConfettiEffect> createState() => _ConfettiEffectState();
}

class _ConfettiEffectState extends State<_ConfettiEffect> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final List<_Confetto> _p = List.generate(40, (i) => _Confetto());

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => CustomPaint(painter: _ConfettiPainter(_p, _c.value)),
    );
  }
}

class _Confetto {
  double x = math.Random().nextDouble();
  double y = -0.1;
  double vx = math.Random().nextDouble() * 0.02 - 0.01;
  double vy = math.Random().nextDouble() * 0.05 + 0.02;
  Color color = [kGreen, kAmber, kTeal, kPink, kBlue][math.Random().nextInt(5)];
  double size = math.Random().nextDouble() * 8 + 4;
  double rot = math.Random().nextDouble() * 2 * math.pi;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> p;
  final double progress;
  _ConfettiPainter(this.p, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var c in p) {
      final x = c.x * size.width + (c.vx * progress * size.width);
      final y = (c.y + c.vy * progress) * size.height;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.rot + progress * 5);
      canvas.drawRect(Rect.fromLTWH(0, 0, c.size, c.size / 2), Paint()..color = c.color.withOpacity(1.0 - progress));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
