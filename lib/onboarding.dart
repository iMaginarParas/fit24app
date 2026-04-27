// onboarding.dart
// ─────────────────────────────────────────────────────────────────────────────
// 9-step onboarding flow shown once after first login.
// Steps: Gender → Age → Weight → Height → Goal → Focus Area →
//        Exercise Frequency → Exercise Types → Location
//
// Data is saved to the backend (POST /profile/setup) and cached locally.
// AuthGate checks SharedPreferences for 'onboarding_done' to skip on return.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state.dart';
import 'shell.dart';

const _kBaseUrl = 'https://fit24bc-production.up.railway.app';
const kOnboardingDoneKey = 'onboarding_done';

// ── Data model collected across steps ────────────────────────────────────────
class OnboardingData {
  String name          = '';
  String gender        = '';
  int    age           = 26;
  double weight        = 74;   // kg
  int    height        = 170;  // cm
  int    dailyGoal     = 8000;
  List<String> focusAreas   = [];
  String exerciseFreq  = '';
  List<String> exerciseTypes = [];
  String city          = '';

  Map<String, dynamic> toJson() => {
    'name'           : name,
    'gender'         : gender,
    'age'            : age,
    'weight_kg'      : weight,
    'height_cm'      : height,
    'daily_goal'     : dailyGoal,
    'focus_areas'    : focusAreas,
    'exercise_freq'  : exerciseFreq,
    'exercise_types' : exerciseTypes,
    'city'           : city,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingFlow
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with TickerProviderStateMixin {

  final PageController _page = PageController();
  int _step = 0;
  static const _total = 10;
  bool _saving = false;
  String? _error;

  final _data = OnboardingData();

  // ── navigation ───────────────────────────────────────────────────────────────

  void _next() {
    if (_step < _total - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      _page.previousPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });

    // Read token directly from SharedPreferences — Riverpod authProvider may
    // not have hydrated yet when onboarding runs immediately after first login.
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('auth_access_token') ?? '';

    if (accessToken.isEmpty) {
      setState(() {
        _error = 'Session expired. Please log in again.';
        _saving = false;
      });
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/profile/setup'),
        headers: {
          'Content-Type'  : 'application/json',
          'Authorization' : 'Bearer $accessToken',
        },
        body: jsonEncode(_data.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await prefs.setBool(kOnboardingDoneKey, true);
        await prefs.setString('profile_data', jsonEncode(_data.toJson()));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (_) => false,
          );
        }
      } else {
        final b = jsonDecode(res.body);
        setState(() => _error = b['detail'] ?? 'Failed to save. Try again.');
      }
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar: logo + progress dots ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              Row(children: [
                // Logo
                Image.asset('assets/logo.png', width: 36, height: 36),
                const SizedBox(width: 8),
                const Text('FIT24', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 2)),
                const Spacer(),
                if (_step > 0)
                  GestureDetector(
                    onTap: _back,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: kCard, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: Colors.white.withOpacity(0.6)),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              // Progress dots — connected line style like Figma
              _ProgressDots(current: _step, total: _total),
            ]),
          ),

          // ── Page content ───────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _NameStep(data: _data, onChanged: setState),
                _GenderStep(data: _data, onChanged: setState),
                _AgeStep(data: _data, onChanged: setState),
                _WeightStep(data: _data, onChanged: setState),
                _HeightStep(data: _data, onChanged: setState),
                _GoalStep(data: _data, onChanged: setState),
                _FocusStep(data: _data, onChanged: setState),
                _FrequencyStep(data: _data, onChanged: setState),
                _ExerciseTypeStep(data: _data, onChanged: setState),
                _LocationStep(data: _data, onChanged: setState),
              ],
            ),
          ),

          // ── Error ──────────────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kCoral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCoral.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: kCoral, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(fontSize: 12, color: kCoral))),
                ]),
              ),
            ),

          // ── Next button ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: GestureDetector(
              onTap: (_saving || !_canProceed()) ? null : _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: (_saving || !_canProceed()) ? null : kGreenGrad,
                  color: (_saving || !_canProceed()) ? kCard2 : null,
                  borderRadius: BorderRadius.circular(18),
                  border: (_saving || !_canProceed())
                      ? Border.all(color: kBorder) : null,
                  boxShadow: (_saving || !_canProceed()) ? [] : [
                    BoxShadow(color: kGreen.withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 7)),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white.withOpacity(0.5)))
                      : Text(
                          _step == _total - 1 ? 'Get Started  🚀' : 'Next',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: (_saving || !_canProceed())
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0: return _data.name.trim().length >= 2;
      case 1: return _data.gender.isNotEmpty;
      case 5: return _data.dailyGoal > 0;
      case 6: return _data.focusAreas.isNotEmpty;
      case 7: return _data.exerciseFreq.isNotEmpty;
      case 8: return _data.exerciseTypes.isNotEmpty;
      default: return true;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress dots widget
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressDots extends StatelessWidget {
  final int current, total;
  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done    = i < current;
        final active  = i == current;
        return Expanded(
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: active ? 20 : 8, height: 8,
              decoration: BoxDecoration(
                color: done
                    ? kGreen
                    : active
                        ? kGreen
                        : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
                boxShadow: active ? [
                  BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 8)
                ] : [],
              ),
            ),
            if (i < total - 1)
              Expanded(child: Container(height: 2,
                color: done ? kGreen.withOpacity(0.5) : Colors.white.withOpacity(0.07))),
          ]),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared step scaffold
// ─────────────────────────────────────────────────────────────────────────────
class _StepShell extends StatelessWidget {
  final String question;
  final String? subtitle;
  final Widget child;
  const _StepShell({required this.question, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(question, style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.2)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.35), height: 1.5)),
        ],
        const SizedBox(height: 32),
        Expanded(child: child),
      ],
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Name
// ─────────────────────────────────────────────────────────────────────────────
class _NameStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _NameStep({required this.data, required this.onChanged});
  @override State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.data.name);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _StepShell(
    question: "What's Your\nName?",
    subtitle: "This is how we'll greet you in the app.",
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 0.5),
            decoration: InputDecoration(
              hintText: 'Your full name',
              hintStyle: TextStyle(
                  fontSize: 22, color: Colors.white.withOpacity(0.15),
                  fontWeight: FontWeight.w600),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 22),
            ),
            onChanged: (v) => widget.onChanged(() => widget.data.name = v),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.data.name.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGreen.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Text('👋  ', style: TextStyle(fontSize: 18)),
              Expanded(child: Text(
                'Hey \${widget.data.name.trim().split(' ').first}, welcome to Fit24!',
                style: TextStyle(fontSize: 14, color: kGreen.withOpacity(0.9),
                    fontWeight: FontWeight.w600),
              )),
            ]),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Gender
// ─────────────────────────────────────────────────────────────────────────────
class _GenderStep extends StatelessWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _GenderStep({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'What Is Your Gender?',
    child: Row(
      children: [
        _GenderCard('Male',   '🧍‍♂️', data.gender == 'male', () {
          onChanged(() => data.gender = 'male');
        }),
        const SizedBox(width: 16),
        _GenderCard('Female', '🧍‍♀️', data.gender == 'female', () {
          onChanged(() => data.gender = 'female');
        }),
      ],
    ),
  );
}

class _GenderCard extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _GenderCard(this.label, this.emoji, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 200,
        decoration: BoxDecoration(
          color: selected ? kGreen.withOpacity(0.12) : kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? kGreen : kBorder,
              width: selected ? 2 : 1),
          boxShadow: selected ? [
            BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 20)
          ] : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: selected ? kGreen : Colors.white)),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Age  (drum-roll picker)
// ─────────────────────────────────────────────────────────────────────────────
class _AgeStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _AgeStep({required this.data, required this.onChanged});
  @override State<_AgeStep> createState() => _AgeStepState();
}
class _AgeStepState extends State<_AgeStep> {
  late FixedExtentScrollController _ctrl;
  static const _min = 10, _max = 80;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.data.age - _min);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'How Old Are You?',
    child: Center(child: _DrumPicker(
      controller: _ctrl,
      values: List.generate(_max - _min + 1, (i) => '${i + _min}'),
      unit: 'Years',
      selected: widget.data.age - _min,
      onSelected: (i) => widget.onChanged(() => widget.data.age = i + _min),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Weight
// ─────────────────────────────────────────────────────────────────────────────
class _WeightStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _WeightStep({required this.data, required this.onChanged});
  @override State<_WeightStep> createState() => _WeightStepState();
}
class _WeightStepState extends State<_WeightStep> {
  late FixedExtentScrollController _ctrl;
  static const _min = 30, _max = 200;
  @override void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(
        initialItem: widget.data.weight.toInt() - _min);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'What Is Your Weight?',
    child: Center(child: _DrumPicker(
      controller: _ctrl,
      values: List.generate(_max - _min + 1, (i) => '${i + _min}'),
      unit: 'Kg',
      selected: widget.data.weight.toInt() - _min,
      onSelected: (i) => widget.onChanged(() => widget.data.weight = (i + _min).toDouble()),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Height
// ─────────────────────────────────────────────────────────────────────────────
class _HeightStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _HeightStep({required this.data, required this.onChanged});
  @override State<_HeightStep> createState() => _HeightStepState();
}
class _HeightStepState extends State<_HeightStep> {
  late FixedExtentScrollController _ctrl;
  static const _min = 100, _max = 250;
  @override void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.data.height - _min);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'What Is Your Height?',
    child: Center(child: _DrumPicker(
      controller: _ctrl,
      values: List.generate(_max - _min + 1, (i) => '${i + _min}'),
      unit: 'Cm',
      selected: widget.data.height - _min,
      onSelected: (i) => widget.onChanged(() => widget.data.height = i + _min),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared drum-roll picker widget
// ─────────────────────────────────────────────────────────────────────────────
class _DrumPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<String> values;
  final String unit;
  final int selected;
  final void Function(int) onSelected;
  const _DrumPicker({
    required this.controller, required this.values,
    required this.unit, required this.selected, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(unit, style: TextStyle(
          fontSize: 12, color: Colors.white.withOpacity(0.35),
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      SizedBox(
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          // selection band
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: kGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGreen.withOpacity(0.35), width: 1.5),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 56,
            diameterRatio: 1.8,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelected,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: values.length,
              builder: (ctx, i) {
                final sel = i == selected;
                return Center(
                  child: Text(values[i],
                    style: TextStyle(
                      fontSize: sel ? 36 : 22,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w400,
                      color: sel ? kGreen : Colors.white.withOpacity(0.25),
                    ),
                  ),
                );
              },
            ),
          ),
          // top/bottom fade
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [kBg, kBg.withOpacity(0)]),
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [kBg, kBg.withOpacity(0)]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Daily Goal
// ─────────────────────────────────────────────────────────────────────────────
class _GoalStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _GoalStep({required this.data, required this.onChanged});
  @override State<_GoalStep> createState() => _GoalStepState();
}
class _GoalStepState extends State<_GoalStep> {
  late FixedExtentScrollController _ctrl;
  static const _goals = [3000,4000,5000,6000,7000,8000,9000,10000,12000,15000,20000];
  @override void initState() {
    super.initState();
    final idx = _goals.indexOf(widget.data.dailyGoal);
    _ctrl = FixedExtentScrollController(initialItem: idx < 0 ? 4 : idx);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'What Is Your Goal?',
    subtitle: 'Choose your daily target to stay motivated.',
    child: Center(child: _DrumPicker(
      controller: _ctrl,
      values: _goals.map((g) => g.toString()).toList(),
      unit: 'Steps / Day',
      selected: _goals.indexOf(widget.data.dailyGoal) < 0
          ? 4 : _goals.indexOf(widget.data.dailyGoal),
      onSelected: (i) => widget.onChanged(() => widget.data.dailyGoal = _goals[i]),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 7 — Focus Area  (multi-select chips)
// ─────────────────────────────────────────────────────────────────────────────
class _FocusStep extends StatelessWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _FocusStep({required this.data, required this.onChanged});

  static const _areas = [
    ('Arm',          Icons.fitness_center_rounded),
    ('Chest',        Icons.self_improvement_rounded),
    ('Flat Belly',   Icons.monitor_weight_rounded),
    ('Bubble Booty', Icons.accessibility_new_rounded),
    ('Quads',        Icons.directions_run_rounded),
    ('Back',         Icons.swap_vert_rounded),
    ('Shoulders',    Icons.sports_gymnastics_rounded),
    ('Full Body',    Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) => _StepShell(
    question: "What's Your Focus Area?",
    subtitle: 'Select one or more areas to target.',
    child: GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: _areas.map((a) {
        final sel = data.focusAreas.contains(a.$1.toLowerCase());
        return GestureDetector(
          onTap: () => onChanged(() {
            final k = a.$1.toLowerCase();
            if (sel) data.focusAreas.remove(k);
            else data.focusAreas.add(k);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: sel ? kGreen.withOpacity(0.12) : kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: sel ? kGreen : kBorder,
                  width: sel ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(a.$2, size: 18, color: sel ? kGreen : Colors.white.withOpacity(0.4)),
              const SizedBox(width: 8),
              Text(a.$1, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: sel ? kGreen : Colors.white.withOpacity(0.7))),
            ]),
          ),
        );
      }).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 8 — Exercise Frequency
// ─────────────────────────────────────────────────────────────────────────────
class _FrequencyStep extends StatelessWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _FrequencyStep({required this.data, required this.onChanged});

  static const _opts = [
    ('0–1 Workouts',  'I\'m fairly new',   Icons.hotel_rounded,             kBlue),
    ('2–4 Workouts',  'I\'m a regular',    Icons.directions_run_rounded,    kGreen),
    ('+5 Workouts',   'I\'m for anything', Icons.local_fire_department_rounded, kCoral),
  ];

  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'How Often Do You Exercise?',
    child: Column(
      children: _opts.map((o) {
        final sel = data.exerciseFreq == o.$1;
        return GestureDetector(
          onTap: () => onChanged(() => data.exerciseFreq = o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: sel ? (o.$4 as Color).withOpacity(0.12) : kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: sel ? (o.$4 as Color) : kBorder,
                  width: sel ? 1.5 : 1),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (o.$4 as Color).withOpacity(sel ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(o.$3 as IconData, color: o.$4 as Color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.$1, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: sel ? o.$4 as Color : Colors.white)),
                const SizedBox(height: 2),
                Text(o.$2, style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.35))),
              ]),
              const Spacer(),
              if (sel) Icon(Icons.check_circle_rounded, color: o.$4 as Color, size: 22),
            ]),
          ),
        );
      }).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 9 — Exercise Types  (pill chips)
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseTypeStep extends StatelessWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _ExerciseTypeStep({required this.data, required this.onChanged});

  static const _types = [
    'Yoga','Meditation','Gym','Cycling','Running',
    'Walking','Swimming','Home Workout','Rope Skipping',
    'HIIT','Pilates','CrossFit',
  ];

  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'Select all your\nfavorite type of Exercise',
    child: Wrap(
      spacing: 10, runSpacing: 10,
      children: _types.map((t) {
        final sel = data.exerciseTypes.contains(t.toLowerCase());
        return GestureDetector(
          onTap: () => onChanged(() {
            final k = t.toLowerCase();
            if (sel) data.exerciseTypes.remove(k);
            else data.exerciseTypes.add(k);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? kGreen.withOpacity(0.15) : kCard,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: sel ? kGreen : kBorder,
                  width: sel ? 1.5 : 1),
              boxShadow: sel ? [
                BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 10)
              ] : [],
            ),
            child: Text(t, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: sel ? kGreen : Colors.white.withOpacity(0.55))),
          ),
        );
      }).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 10 — Location (city text input + map illustration)
// ─────────────────────────────────────────────────────────────────────────────
class _LocationStep extends StatefulWidget {
  final OnboardingData data;
  final void Function(void Function()) onChanged;
  const _LocationStep({required this.data, required this.onChanged});
  @override State<_LocationStep> createState() => _LocationStepState();
}
class _LocationStepState extends State<_LocationStep> {
  late TextEditingController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.data.city);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _StepShell(
    question: 'Select Your Location',
    subtitle: 'We\'ll personalise your experience.',
    child: Column(children: [
      // Map illustration card
      Container(
        height: 180,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGreen.withOpacity(0.25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            // Grid lines as map stand-in
            CustomPaint(painter: _MapGridPainter(), size: Size.infinite),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: kGreen,
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.5), blurRadius: 14)],
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.black, size: 24),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kBg.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: Text(
                  widget.data.city.isNotEmpty ? widget.data.city : 'Your City',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      // City input
      Container(
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.search_rounded, color: kGreen, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(fontSize: 15, color: Colors.white,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Enter your city (e.g. Bhopal)',
                hintStyle: TextStyle(
                    fontSize: 14, color: Colors.white.withOpacity(0.2)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (v) => widget.onChanged(() => widget.data.city = v),
            ),
          ),
        ]),
      ),
    ]),
  );
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kGreen.withOpacity(0.08)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Roads
    final road = Paint()
      ..color = kGreen.withOpacity(0.18)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.55), road);
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.45, size.height), road);
  }
  @override bool shouldRepaint(_) => false;
}