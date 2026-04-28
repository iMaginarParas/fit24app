import 'dart:ui';
import 'package:flutter/material.dart';
import 'home.dart';
import 'earn.dart';
import 'activity.dart';
import 'profile.dart';
import 'tracking_page.dart';

// ── TOKENS ───────────────────────────────────────────────────────────────────
const kBg      = Color(0xFF0A0D0F);
const kSurface = Color(0xFF111418);
const kCard    = Color(0xFF181D22);
const kCard2   = Color(0xFF1E2530);

// Brighter, Figma-accurate greens + accents
const kGreen   = Color(0xFF2ECC71);   // primary action green
const kGreen2  = Color(0xFF00FF88);   // electric highlight
const kGreenDim= Color(0xFF1A5C35);   // muted green bg
const kAmber   = Color(0xFFFFB020);   // warm gold
const kBlue    = Color(0xFF3B82F6);   // cool blue
const kCoral   = Color(0xFFFF5757);   // red/coral
const kPurple  = Color(0xFF8B5CF6);   // purple
const kTeal    = Color(0xFF06B6D4);   // teal
const kPink    = Color(0xFFFF007F);   // neon pink
const kBorder  = Color(0xFF252D36);

// Figma green gradient
const kGreenGrad = LinearGradient(
  colors: [Color(0xFF2ECC71), Color(0xFF00BFA5)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;
  static const _pages = [HomePage(), EarnPage(), ActivityPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: _Nav(current: _i, onTap: (i) => setState(() => _i = i)),
    );
  }
}

class _Nav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _Nav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Like Figma: Home, Earn, Activity, Profile
    final items = [
      (Icons.home_rounded,       Icons.home_outlined,         'Home'),
      (Icons.bolt_rounded,       Icons.bolt_outlined,         'Earn'),
      (Icons.bar_chart_rounded,  Icons.bar_chart_outlined,    'Activity'),
      (Icons.person_rounded,     Icons.person_outlined,       'Profile'),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface.withOpacity(0.97),
            border: const Border(top: BorderSide(color: kBorder, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _navItem(0, items[0], current, onTap),
                  _navItem(1, items[1], current, onTap),
                  _centerLogoBtn(context),
                  _navItem(2, items[2], current, onTap),
                  _navItem(3, items[3], current, onTap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, (IconData, IconData, String) item, int current, ValueChanged<int> onTap) {
    final sel = current == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: sel ? BoxDecoration(
            color: kGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGreen.withOpacity(0.4), width: 1),
          ) : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(sel ? item.$1 : item.$2,
              size: 22,
              color: sel ? kGreen : Colors.white.withOpacity(0.3)),
            const SizedBox(height: 4),
            Text(item.$3, style: TextStyle(
              fontSize: 10,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? kGreen : Colors.white.withOpacity(0.3),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _centerLogoBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingPage())),
      child: Container(
        width: 72, height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kSurface,
          shape: BoxShape.circle,
          border: Border.all(color: kGreen, width: 2.5),
          boxShadow: [
            BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 24, spreadRadius: 3)
          ],
        ),
        child: Hero(
          tag: 'logo',
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

/// Avatar circle — like Figma trainer cards
class AvatarCircle extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final bool online;
  final String? imagePath;
  final String? gender;
  const AvatarCircle(this.initials, this.color,
      {super.key, this.size = 52, this.online = false, this.imagePath, this.gender});

  @override
  Widget build(BuildContext context) {
    String? effectivePath = imagePath;
    if (effectivePath == null) {
      if (gender?.toLowerCase() == 'male') effectivePath = 'assets/images/male_avatar.png';
      else if (gender?.toLowerCase() == 'female') effectivePath = 'assets/images/female_avatar.png';
    }

    return Stack(children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: effectivePath != null ? null : LinearGradient(
            colors: [color, color.withOpacity(0.5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          image: effectivePath != null ? DecorationImage(
            image: (effectivePath.startsWith('http') 
              ? NetworkImage(effectivePath) 
              : AssetImage(effectivePath)) as ImageProvider,
            fit: BoxFit.cover,
          ) : null,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
        ),
        child: effectivePath == null ? Center(child: Text(initials,
          style: const TextStyle(fontWeight: FontWeight.w800,
              color: Colors.white, fontSize: 16))) : null,
      ),
      if (online) Positioned(bottom: 2, right: 2, child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: kGreen,
          border: Border.all(color: kBg, width: 2),
        ),
      )),
    ]);
  }
}

/// Pill chip
class Chip24 extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const Chip24(this.label, {super.key, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: filled ? color : color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: filled ? color : color.withOpacity(0.35), width: 1),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: filled ? Colors.black : color,
    )),
  );
}

/// Green CTA button — like Figma
class GreenBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  const GreenBtn(this.label, {super.key, required this.onTap, this.width});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: width ?? double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: kGreenGrad,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: kGreen.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Text(label, textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
    ),
  );
}

/// Section header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Row(children: [
      Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kGreen)),
        ),
    ]),
  );
}