import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
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
    SpinSlot('50 PTS', 50, const Color(0xFFFF3D00), Icons.fitness_center_rounded),
    SpinSlot('60 PTS', 60, Colors.white, Icons.directions_run_rounded),
    SpinSlot('70 PTS', 70, const Color(0xFFFF3D00), Icons.bolt_rounded),
    SpinSlot('TRY AGAIN', 0, Colors.white, Icons.sentiment_dissatisfied_rounded),
    SpinSlot('80 PTS', 80, const Color(0xFFFF3D00), Icons.timer_rounded),
    SpinSlot('100 PTS', 100, Colors.white, Icons.emoji_events_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
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

    final rand = math.Random();
    final winIndex = rand.nextInt(_slots.length);
    
    final sliceAngle = 2 * math.pi / _slots.length;
    final targetAngle = (12 * 2 * math.pi) - (winIndex * sliceAngle) - (sliceAngle / 2);

    _anim = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 1.0, curve: Curves.easeOutQuart))
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
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  _GlowOrb(color: slot.points > 0 ? kGreen.withOpacity(0.4) : Colors.red.withOpacity(0.4), size: 120),
                  Icon(slot.icon, color: slot.points > 0 ? kGreen : Colors.white54, size: 70),
                ],
              ),
              const SizedBox(height: 24),
              Text(slot.points > 0 ? 'LEGENDARY WIN!' : 'BETTER LUCK', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Text(slot.points > 0 
                  ? 'You grabbed ${slot.points} FIT24 points!\nYour rewards have been added to your vault.'
                  : 'The wheel didn\'t stop on a prize this time.\nCome back in 24 hours for another shot!',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: slot.points > 0 ? kGreenGrad : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      if (slot.points > 0) BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Center(
                    child: Text(slot.points > 0 ? 'CLAIM REWARD' : 'CLOSE', 
                      style: TextStyle(color: slot.points > 0 ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05)),
          ),
        ),
        title: const Text('Luck of the Day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Particles & Gradients
          const Positioned.fill(child: _PremiumBackground()),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text('DAILY REWARDS', style: TextStyle(color: kGreen, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 3)),
                const SizedBox(height: 8),
                const Text('Spin & Win', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 48, fontStyle: FontStyle.italic, letterSpacing: -1.5)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Unlock exclusive fitness points and premium rewards every 24 hours.', 
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const Spacer(),
                
                // The Wheel Section
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Glow
                      _GlowOrb(color: Colors.amber.withOpacity(0.1), size: 380),
                      
                      // The Wheel itself
                      Container(
                        width: 320, height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 40, spreadRadius: 10),
                            BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 60),
                          ],
                        ),
                        child: ClipOval(
                          child: AnimatedBuilder(
                            animation: _ctrl,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _ctrl.isAnimating || _ctrl.isCompleted ? _anim.value : 0,
                                child: CustomPaint(
                                  painter: PremiumWheelPainter(_slots),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      // Light Bulbs Ring
                      IgnorePointer(
                        child: SizedBox(
                          width: 336, height: 336,
                          child: CustomPaint(painter: BulbsPainter()),
                        ),
                      ),

                      // Center Hub (3D Look)
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                            const BoxShadow(color: Colors.white24, blurRadius: 5, offset: Offset(-2, -2)),
                          ],
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFECB3), Color(0xFFFFD54F), Color(0xFFFFA000)],
                            stops: [0, 0.6, 1],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 40, height: 40,
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      
                      // Top Pointer (Metallic Style)
                      Positioned(
                        top: -10,
                        child: Column(
                          children: [
                            Container(
                              width: 30, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
                                ],
                              ),
                              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black, size: 24),
                            ),
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white, blurRadius: 8)]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Section: Button & Countdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      // Countdown Glassmorphism Card
                      if (_hasSpunToday && _timeLeft != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                                  const SizedBox(width: 12),
                                  Text('NEXT SPIN IN ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                                  Text(_formatDuration(_timeLeft!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // Main Action Button
                      GestureDetector(
                        onTap: _spin,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            gradient: _hasSpunToday ? null : kGreenGrad,
                            color: _hasSpunToday ? Colors.white.withOpacity(0.05) : null,
                            borderRadius: BorderRadius.circular(24),
                            border: _hasSpunToday ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                            boxShadow: _hasSpunToday ? [] : [
                              BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_hasSpunToday) const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
                                if (!_hasSpunToday) const SizedBox(width: 8),
                                Text(
                                  _hasSpunToday ? 'ALREADY CLAIMED' : (_spinning ? 'SPINNING...' : 'SPIN NOW'), 
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w900, 
                                    color: _hasSpunToday ? Colors.white.withOpacity(0.3) : Colors.black,
                                    letterSpacing: 1,
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Confetti Overlay
          if (_ctrl.isCompleted && !_spinning)
            const Positioned.fill(child: IgnorePointer(child: _ConfettiEffect())),
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

class PremiumWheelPainter extends CustomPainter {
  final List<SpinSlot> slots;
  PremiumWheelPainter(this.slots);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final sliceAngle = 2 * math.pi / slots.length;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < slots.length; i++) {
      final startAngle = i * sliceAngle - math.pi / 2;
      
      // Slice Fill with Gradient
      final slicePaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            slots[i].color,
            slots[i].color.withOpacity(0.85),
            slots[i].color.withOpacity(0.7),
          ],
          [0, 0.7, 1],
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(rect, startAngle, sliceAngle, true, slicePaint);

      // Slice Borders
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(rect, startAngle, sliceAngle, true, borderPaint);

      // Text and Icons
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * sliceAngle + sliceAngle / 2 - math.pi / 2);
      
      final textColor = slots[i].color == Colors.white ? const Color(0xFFFF3D00) : Colors.white;

      // Icon
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(slots[i].icon.codePoint),
          style: TextStyle(
            fontSize: 26,
            fontFamily: slots[i].icon.fontFamily,
            package: slots[i].icon.fontPackage,
            color: textColor.withOpacity(0.9),
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(radius * 0.6, -iconPainter.height / 2));

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: slots[i].label,
          style: TextStyle(
            color: textColor, 
            fontWeight: FontWeight.w900, 
            fontSize: 10, 
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.3, -textPainter.height / 2));
      
      canvas.restore();
    }
    
    // Glossy Overlay
    final glossyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, 0),
        Offset(center.dx, size.height),
        [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
          Colors.black.withOpacity(0.1),
        ],
        [0, 0.5, 1],
      );
    canvas.drawCircle(center, radius, glossyPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BulbsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    for (int i = 0; i < 16; i++) {
      final angle = (i * 2 * math.pi / 16) - math.pi / 2;
      final bulbPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      // Glow
      canvas.drawCircle(
        bulbPos, 8,
        Paint()..color = Colors.amber.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      
      // Core
      canvas.drawCircle(
        bulbPos, 4,
        Paint()..color = const Color(0xFFFFF9C4),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF08090A), Color(0xFF121417), Color(0xFF08090A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100, left: -100,
            child: _GlowOrb(color: const Color(0xFF2E7D32).withOpacity(0.08), size: 400),
          ),
          Positioned(
            bottom: -150, right: -150,
            child: _GlowOrb(color: const Color(0xFF00695C).withOpacity(0.1), size: 500),
          ),
          // Floating Particles could be added here as a CustomPaint
        ],
      ),
    );
  }
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
        boxShadow: [BoxShadow(color: color, blurRadius: size / 2.5, spreadRadius: size / 5)],
      ),
    );
  }
}

class _ConfettiEffect extends StatefulWidget {
  const _ConfettiEffect();
  @override
  State<_ConfettiEffect> createState() => _ConfettiEffectState();
}

class _ConfettiEffectState extends State<_ConfettiEffect> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final List<_Confetto> _p = List.generate(60, (i) => _Confetto());

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();
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
  double vx = math.Random().nextDouble() * 0.04 - 0.02;
  double vy = math.Random().nextDouble() * 0.06 + 0.03;
  Color color = [kGreen, kAmber, Colors.white, Colors.redAccent, Colors.blueAccent][math.Random().nextInt(5)];
  double size = math.Random().nextDouble() * 10 + 5;
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
      canvas.rotate(c.rot + progress * 8);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, c.size, c.size / 2.5), 
        Paint()..color = c.color.withOpacity(1.0 - progress)..style = PaintingStyle.fill
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
