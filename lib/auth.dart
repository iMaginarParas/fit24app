// auth.dart
// ─────────────────────────────────────────────────────────────────────────────
// Fit24 Authentication UI
// Flow: Email input → Send OTP → 6-box OTP entry → Verify → AppShell
// Also supports Sign in with Google.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_state.dart';
import 'onboarding.dart';
import 'slideshow.dart';
import 'shell.dart';
import 'config_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate — handles app routing (Splash → Slideshow → Auth → Home)
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

enum _Route { loading, slideshow, auth, onboarding, home }

class _AuthGateState extends ConsumerState<AuthGate> {
  _Route _route = _Route.loading;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken  = prefs.getString('auth_access_token') ?? '';
    final storedUserId = prefs.getString('auth_user_id')      ?? '';

    if (storedToken.isEmpty || storedUserId.isEmpty) {
      final slideshowSeen = prefs.getBool('slideshow_seen') ?? false;
      if (!slideshowSeen) {
        if (!mounted) return;
        setState(() => _route = _Route.slideshow);
        return;
      }
      if (!mounted) return;
      setState(() => _route = _Route.auth);
      return;
    }

    final localDone = prefs.getBool(kOnboardingDoneKey) ?? false;
    if (localDone) {
      if (!mounted) return;
      setState(() => _route = _Route.home);
      _refreshProfile(storedToken, prefs);
      return;
    }

    try {
      await ref.read(configProvider.notifier).fetchKeys();
      final res = await http.get(
        Uri.parse('$kBaseUrl/profile/me'),
        headers: {'Authorization': 'Bearer $storedToken'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final profile = jsonDecode(res.body) as Map<String, dynamic>;
        final hasProfile = (profile['name'] as String? ?? '').trim().isNotEmpty;
        await prefs.setString('profile_data', jsonEncode(profile));
        if (hasProfile) await prefs.setBool(kOnboardingDoneKey, true);
        if (!mounted) return;
        setState(() => _route = hasProfile ? _Route.home : _Route.onboarding);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _route = _Route.home);
  }

  Future<void> _refreshProfile(String token, SharedPreferences prefs) async {
    try {
      await ref.read(configProvider.notifier).fetchKeys();
      final res = await http.get(
        Uri.parse('$kBaseUrl/profile/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        await prefs.setString('profile_data', res.body);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      final prevSession = prev?.valueOrNull;
      final nextSession = next.valueOrNull;
      if ((prevSession == null && nextSession != null) || (prevSession != null && nextSession == null)) {
        _resolve();
      }
    });

    switch (_route) {
      case _Route.loading:    return const _SplashScreen();
      case _Route.slideshow:  return SlideshowPage(onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('slideshow_seen', true);
        setState(() => _route = _Route.auth);
      });
      case _Route.auth:       return const AuthScreen();
      case _Route.onboarding: return const OnboardingFlow();
      case _Route.home:       return const AppShell();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), shape: BoxShape.circle),
            child: Image.asset('assets/logo.png', width: 60, height: 60),
          ),
          const SizedBox(height: 20),
          RichText(text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
            children: [
              TextSpan(text: 'FIT', style: TextStyle(color: Colors.white)),
              TextSpan(text: '24', style: TextStyle(color: kGreen)),
            ],
          )),
          const SizedBox(height: 48),
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kGreen.withOpacity(0.6))),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────────────────────────────────────
enum _Step { email, otp }
enum _Mode { signup, login }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  _Step _step = _Step.email;
  _Mode _mode = _Mode.signup;

  final _emailCtrl = TextEditingController();
  final _otpCtrls  = List.generate(6, (_) => TextEditingController());
  final _otpFocus  = List.generate(6, (_) => FocusNode());

  bool    _loading   = false;
  String? _error;
  int     _countdown = 0;
  Timer?  _timer;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();
  String get _otp => _otpCtrls.map((c) => c.text.trim()).join();

  void _err(String? msg) => setState(() => _error = msg);

  void _startCountdown([int secs = 60]) {
    _timer?.cancel();
    setState(() => _countdown = secs);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown <= 1) { _timer?.cancel(); setState(() => _countdown = 0); }
      else setState(() => _countdown--);
    });
  }

  void _toOtp() {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() { _step = _Step.otp; _error = null; });
      _fadeCtrl.forward();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _otpFocus[0].requestFocus();
      });
    });
  }

  void _toEmail() {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() { _step = _Step.email; _error = null; });
      _fadeCtrl.forward();
    });
  }

  Future<void> _sendOtp() async {
    if (!_email.contains('@') || !_email.contains('.')) { 
      _err('Enter a valid email address'); 
      return; 
    }

    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendOtp(
        email: _email,
        mode: _mode.name,
      );
      _toOtp();
      _startCountdown();
    } catch (e) {
      _err(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otp;
    if (token.length != 6) { _err('Enter all 6 digits'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final b = await api.verifyOtp(
        email: _email,
        token: token,
        mode: _mode.name,
      );
      
      await ref.read(authProvider.notifier).signIn(
        accessToken:  b['tokens']['access_token'],
        refreshToken: b['tokens']['refresh_token'],
        userId:       b['user']['id'],
        email:        b['user']['email'],
        phone:        b['user']['phone'],
      );
    } catch (e) {
      _err(e.toString().replaceAll('Exception: ', ''));
      for (final c in _otpCtrls) c.clear();
      if (mounted) _otpFocus[0].requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '268016745351-l2dddrhhjhrbc92iesp7g1fat07aautf.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) { setState(() => _loading = false); return; }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Failed to get ID token');

      final api = ref.read(apiServiceProvider);
      final b = await api.signInWithGoogle(idToken);

      await ref.read(authProvider.notifier).signIn(
        accessToken: b['tokens']['access_token'],
        refreshToken: b['tokens']['refresh_token'],
        userId: b['user']['id'],
        email: b['user']['email'],
        phone: b['user']['phone'],
      );
    } catch (e) {
      _err('Google Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Stack(children: [
          Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover, color: Colors.black.withOpacity(0.3), colorBlendMode: BlendMode.darken)),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(-0.6, -0.6), radius: 1.2, colors: [kGreen.withOpacity(0.15), Colors.transparent])))),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    _logo(),
                    const SizedBox(height: 32),
                    if (_step == _Step.otp) _backBtn(),
                    _titleSection(),
                    const SizedBox(height: 48),
                    if (_step == _Step.email) _emailField(),
                    if (_step == _Step.otp) _otpStep(),
                    const SizedBox(height: 28),
                    if (_error != null) ...[_errorBanner(), const SizedBox(height: 12)],
                    _primaryBtn(),
                    const SizedBox(height: 24),
                    if (_step == _Step.email) ...[
                      _googleBtn(),
                      const SizedBox(height: 24),
                      _modeToggle(),
                    ],
                    if (_step == _Step.otp) _resendRow(),
                    const SizedBox(height: 40),
                    _termsNote(),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _backBtn() => GestureDetector(
    onTap: _toEmail,
    child: Container(
      width: 42, height: 42, margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(13), border: Border.all(color: kBorder)),
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white70),
    ),
  );

  Widget _logo() => Row(children: [Image.network('https://www.image2url.com/r2/default/images/1776158261618-440cb3d6-dcff-4851-9f4e-0d6ffc5851d8.png', height: 72)]);

  Widget _titleSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_step == _Step.email ? (_mode == _Mode.signup ? 'Create\nAccount' : 'Welcome\nBack') : 'Verify\nEmail',
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05, letterSpacing: -1.5)),
      const SizedBox(height: 12),
      Text(_step == _Step.email ? 'Sign in with your email address.' : 'We sent a 6-digit code to $_email',
        style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.4), height: 1.5)),
    ],
  );

  Widget _emailField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white38)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder)),
        child: TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'name@example.com', 
            hintStyle: TextStyle(color: Colors.white10),
            border: InputBorder.none, 
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 17)
          ),
          onSubmitted: (_) => _sendOtp(),
        ),
      ),
    ],
  );

  Widget _otpStep() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, _otpBox));

  Widget _otpBox(int i) => SizedBox(
    width: 46, height: 58,
    child: TextField(
      controller: _otpCtrls[i], focusNode: _otpFocus[i], keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
      decoration: InputDecoration(counterText: '', filled: true, fillColor: kCard,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGreen, width: 2))),
      onChanged: (val) {
        if (val.isNotEmpty && i < 5) _otpFocus[i+1].requestFocus();
        if (val.isEmpty && i > 0) _otpFocus[i-1].requestFocus();
        if (_otp.length == 6) _verifyOtp();
      },
    ),
  );

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: kCoral.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: kCoral.withOpacity(0.3))),
    child: Row(children: [const Icon(Icons.error_outline_rounded, color: kCoral, size: 18), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: kCoral)))]),
  );

  Widget _primaryBtn() => GreenBtn(_loading ? '...' : (_step == _Step.email ? 'Send OTP' : 'Verify'), onTap: _loading ? () {} : (_step == _Step.email ? _sendOtp : _verifyOtp));

  Widget _googleBtn() => GestureDetector(
    onTap: _loading ? null : _signInWithGoogle,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/images/google_logo.png', height: 24),
        const SizedBox(width: 12),
        const Text('Sign in with Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _modeToggle() => Center(
    child: GestureDetector(
      onTap: () => setState(() => _mode = _mode == _Mode.signup ? _Mode.login : _Mode.signup),
      child: RichText(text: TextSpan(style: const TextStyle(fontSize: 14), children: [
        TextSpan(text: _mode == _Mode.signup ? 'Already have an account? ' : 'Don\'t have an account? ', style: const TextStyle(color: Colors.white38)),
        TextSpan(text: _mode == _Mode.signup ? 'Log In' : 'Sign Up', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
      ])),
    ),
  );

  Widget _resendRow() => Center(
    child: _countdown > 0 
      ? Text('Resend code in ${_countdown}s', style: const TextStyle(color: Colors.white38, fontSize: 13))
      : GestureDetector(onTap: _sendOtp, child: const Text('Resend Code', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 13))),
  );

  Widget _termsNote() => Center(child: Text('By continuing, you agree to our Terms and Privacy Policy.', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)));
}