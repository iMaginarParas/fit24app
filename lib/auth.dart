// auth.dart
// ─────────────────────────────────────────────────────────────────────────────
// Fit24 Phone-OTP Authentication UI
// Flow: Phone input → Send OTP → 6-box OTP entry → Verify → AppShell
// Uses Riverpod authProvider (auth_state.dart) to persist session.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'api_service.dart';
import 'auth_state.dart';
import 'onboarding.dart';
import 'slideshow.dart';
import 'shell.dart';
import 'config_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ── API base ──────────────────────────────────────────────────────────────────
// API base (managed by ApiService)


// ─────────────────────────────────────────────────────────────────────────────
// AuthGate — single widget that handles the full app routing:
//   No session       → AuthScreen
//   Session + done   → AppShell
//   Session + new    → OnboardingFlow
//
// Routing is determined by checking the backend profile (source of truth),
// NOT by a local flag — so it works correctly on every device / reinstall.
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
    // ── Step 1: check SharedPreferences directly (instant, no network) ────────
    // This runs before Riverpod hydrates, so the user sees AuthScreen immediately
    // instead of a blank splash if they have never logged in.
    final prefs = await SharedPreferences.getInstance();
    final storedToken  = prefs.getString('auth_access_token') ?? '';
    final storedUserId = prefs.getString('auth_user_id')      ?? '';

    if (storedToken.isEmpty || storedUserId.isEmpty) {
      // No stored session -> check if slideshow was seen
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

    // ── Step 2: session exists — check local onboarding flag (instant) ────────
    final localDone = prefs.getBool(kOnboardingDoneKey) ?? false;
    if (localDone) {
      // Already onboarded — go straight to AppShell
      if (!mounted) return;
      setState(() => _route = _Route.home);
      // Then refresh profile and keys in background (no await — don't block UI)
      _refreshProfile(storedToken, prefs);
      return;
    }

    // ── Step 3: no local flag — ask backend if profile exists (network) ───────
    // This only runs on first-ever launch after login, or after cache clear.
    try {
      // Fetch keys first
      await ref.read(configProvider.notifier).fetchKeys();

      final res = await http.get(
        Uri.parse('$kBaseUrl/profile/me'),
        headers: {'Authorization': 'Bearer $storedToken'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final profile = jsonDecode(res.body) as Map<String, dynamic>;
        // Profile exists if name field is filled (set during onboarding)
        final hasProfile = (profile['name'] as String? ?? '').trim().isNotEmpty;
        await prefs.setString('profile_data', jsonEncode(profile));
        if (hasProfile) await prefs.setBool(kOnboardingDoneKey, true);
        if (!mounted) return;
        setState(() => _route = hasProfile ? _Route.home : _Route.onboarding);
        return;
      }
    } catch (_) {
      // Network unavailable — no profile cached, no local flag → onboarding
    }

    // ── Step 4: offline, have a token, but no local flag and can't reach backend.
    // Default to home (the user IS authenticated). They'll see onboarding next
    // time the network is available and _resolve re-runs.
    if (!mounted) return;
    setState(() => _route = _Route.home);
  }

  /// Refresh profile from backend in background without blocking navigation.
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
    // Re-resolve only when a new valid session appears (user just signed in)
    // or session becomes null (user signed out). Ignore loading→loaded transitions
    // that happen on hydration, which would cause a spurious double-resolve.
    ref.listen(authProvider, (prev, next) {
      final prevSession = prev?.valueOrNull;
      final nextSession = next.valueOrNull;
      final justSignedIn  = prevSession == null && nextSession != null;
      final justSignedOut = prevSession != null && nextSession == null;
      if (justSignedIn || justSignedOut) _resolve();
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

// ── Splash while checking persisted session ────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    extendBody: true,
    extendBodyBehindAppBar: true,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Image.asset('assets/logo.png', width: 60, height: 60, fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
              children: [
                TextSpan(text: 'FIT', style: TextStyle(color: Colors.white)),
                TextSpan(text: '24', style: TextStyle(color: kGreen)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: kGreen.withOpacity(0.6))),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────────────────────────────────────
enum _Step { phone, otp }
enum _Mode { signup, login }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {

  _Step _step = _Step.phone;
  _Mode _mode = _Mode.signup;

  final _phoneCtrl = TextEditingController();
  final _otpCtrls  = List.generate(6, (_) => TextEditingController());
  final _otpFocus  = List.generate(6, (_) => FocusNode());

  bool    _loading   = false;
  String? _error;
  int     _countdown = 0;
  Timer?  _timer;

  Country _selectedCountry = Country.parse('IN');

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get _e164 {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.startsWith('+')) return raw;
    final dial = _selectedCountry.phoneCode;
    if (raw.startsWith('0')) return '+$dial${raw.substring(1)}';
    return '+$dial$raw';
  }

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

  void _toPhone() {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() { _step = _Step.phone; _error = null; });
      _fadeCtrl.forward();
    });
  }

  // ── API ───────────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = _e164;
    if (phone.length < 12) { _err('Enter a valid 10-digit number'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendOtp(phone, _mode.name);
      _toOtp();
      _startCountdown();
    } catch (e) {
      final detail = e.toString().toLowerCase();

      // Supabase returns an error when trying to signup with an existing phone.
      // Detect common messages and auto-switch to login mode.
      final alreadyExists = detail.contains('already') ||
          detail.contains('registered') ||
          detail.contains('exists') ||
          detail.contains('user already') ||
          detail.contains('duplicate');

      if (alreadyExists && _mode == _Mode.signup) {
        setState(() {
          _mode  = _Mode.login;
          _error = null;
        });
        // Retry immediately in login mode with a friendly banner
        _showAlreadyExistsBanner();
        await _sendOtp();   // recursive — now in login mode
      } else {
        _err(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {

      if (mounted) setState(() => _loading = false);
    }
  }


  void _showAlreadyExistsBanner() {
    // Show a non-blocking snackbar nudge
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        backgroundColor: kAmber.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          const Text('👋', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          const Expanded(child: Text(
            'Looks like you already have an account! Switched to Log In.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700,
                fontSize: 13),
          )),
        ]),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final token = _otp;
    if (token.length != 6) { _err('Enter all 6 digits'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final b = await api.verifyOtp(_e164, token, _mode.name);
      
      final accessToken  = b['tokens']['access_token'] as String;
      final refreshToken = b['tokens']['refresh_token'] as String;
      final userId       = b['user']['id'] as String;
      final phone        = b['user']['phone'] as String? ?? _e164;

      await ref.read(authProvider.notifier).signIn(
        accessToken:  accessToken,
        refreshToken: refreshToken,
        userId:       userId,
        phone:        phone,
      );
      // AuthGate rebuilds automatically
    } catch (e) {
      final detail = e.toString().toLowerCase();
      // Supabase 422: phone already confirmed = existing user tried signup
      final isExisting = detail.contains('already') || 
           detail.contains('confirmed') ||
           detail.contains('registered') || 
           detail.contains('otp');
      
      if (isExisting && _mode == _Mode.signup) {
        setState(() { _mode = _Mode.login; _error = null; });
        for (final c in _otpCtrls) c.clear();
        _showAlreadyExistsBanner();
        if (mounted) _otpFocus[0].requestFocus();
      } else {
        _err(e.toString().replaceAll('Exception: ', ''));
        for (final c in _otpCtrls) c.clear();
        if (mounted) _otpFocus[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '1047128597921-3rgdprug33ohokd3g8t478gi1ndpnaf1.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      final api = ref.read(apiServiceProvider);
      final b = await api.signInWithGoogle(idToken);

      final accessToken = b['tokens']['access_token'] as String;
      final refreshToken = b['tokens']['refresh_token'] as String;
      final userId = b['user']['id'] as String;
      final phone = b['user']['phone'] as String? ?? 'google_user';

      await ref.read(authProvider.notifier).signIn(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        phone: phone,
      );
    } catch (e) {
      _err('Google Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: SizedBox.expand(
        child: Stack(children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.topCenter,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 1.2,
                  colors: [kGreen.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 
                               MediaQuery.of(context).padding.top - 
                               MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _logo(),
                      const SizedBox(height: 32),
                      _topBar(),
                      _titleSection(),
                      const SizedBox(height: 32),
                      if (_step == _Step.phone) _phoneStep(),
                      if (_step == _Step.otp)   _otpStep(),
                      const SizedBox(height: 28),
                      if (_error != null) ...[_errorBanner(), const SizedBox(height: 12)],
                      _primaryBtn(),
                      const SizedBox(height: 16),
                      if (_step == _Step.phone) ...[
                        _googleBtn(),
                        const SizedBox(height: 22),
                        _modeToggle(),
                      ],
                      if (_step == _Step.otp) _resendRow(),
                      const SizedBox(height: 40),
                      _termsNote(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── UI pieces ─────────────────────────────────────────────────────────────────

  Widget _topBar() {
    if (_step == _Step.phone) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _toPhone,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 17, color: Colors.white.withOpacity(0.7)),
      ),
    );
  }

  Widget _logo() => Row(
    children: [
      Image.network(
        'https://www.image2url.com/r2/default/images/1776158261618-440cb3d6-dcff-4851-9f4e-0d6ffc5851d8.png',
        height: 72, 
        fit: BoxFit.contain,
      ),
    ],
  );

  Widget _titleSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _step == _Step.phone
            ? (_mode == _Mode.signup ? 'Create\nAccount' : 'Welcome\nBack')
            : 'Verify Your\nPhone',
        style: const TextStyle(
            fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white,
            height: 1.05, letterSpacing: -1.5),
      ),
      const SizedBox(height: 12),
      Text(
        _step == _Step.phone
            ? (_mode == _Mode.signup
                ? 'Walk, earn, repeat. Start your journey.'
                : 'Good to see you again. Sign in below.')
            : 'We sent a 6-digit code to $_e164',
        style: TextStyle(
            fontSize: 15, color: Colors.white.withOpacity(0.4), height: 1.5),
      ),
    ],
  );

  Widget _phoneStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Mobile Number',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: true,
            onSelect: (c) => setState(() => _selectedCountry = c),
            countryListTheme: CountryListThemeData(
              backgroundColor: kBg,
              textStyle: const TextStyle(color: Colors.white, fontSize: 16),
              searchTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
              inputDecoration: InputDecoration(
                hintText: 'Search country...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                prefixIcon: const Icon(Icons.search, color: kGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: kBorder, width: 1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_selectedCountry.flagEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text('+${_selectedCountry.phoneCode}', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.75))),
                const SizedBox(width: 3),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Colors.white.withOpacity(0.25)),
              ]),
            ),
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    fontSize: 19, color: Colors.white,
                    fontWeight: FontWeight.w700, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: '98765 43210',
                  hintStyle: TextStyle(
                      fontSize: 18, color: Colors.white.withOpacity(0.15),
                      fontWeight: FontWeight.w500, letterSpacing: 2),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                ),
                onSubmitted: (_) => _sendOtp(),
              ),
            ),
          ]),
        ),
      ),
    ],
  );

  Widget _otpStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Enter OTP',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, _otpBox),
      ),
    ],
  );

  Widget _otpBox(int i) => SizedBox(
    width: 46, height: 58,
    child: TextField(
      controller: _otpCtrls[i],
      focusNode:  _otpFocus[i],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: kCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGreen, width: 2),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (val) {
        setState(() => _error = null);
        if (val.isNotEmpty) {
          if (i < 5) _otpFocus[i + 1].requestFocus();
        } else {
          if (i > 0) _otpFocus[i - 1].requestFocus();
        }
        if (_otp.length == 6) _verifyOtp();
      },
    ),
  );

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: kCoral.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kCoral.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: kCoral, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(_error!,
          style: const TextStyle(fontSize: 13, color: kCoral,
              fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _primaryBtn() => GestureDetector(
    onTap: _loading ? null : (_step == _Step.phone ? _sendOtp : _verifyOtp),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        gradient: _loading ? null : kGreenGrad,
        color:    _loading ? kCard : null,
        borderRadius: BorderRadius.circular(18),
        border: _loading ? Border.all(color: kBorder) : null,
        boxShadow: _loading ? [] : [
          BoxShadow(color: kGreen.withOpacity(0.38),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Center(
        child: _loading
            ? SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.45)))
            : Text(
                _step == _Step.phone ? 'Send OTP  →' : 'Verify & Continue  →',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.black),
              ),
      ),
    ),
  );

  Widget _googleBtn() => GestureDetector(
    onTap: _loading ? null : _signInWithGoogle,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded,
                size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            'Continue with Google',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    ),
  );

  Widget _modeToggle() => Center(
    child: GestureDetector(
      onTap: () => setState(() {
        _mode  = _mode == _Mode.signup ? _Mode.login : _Mode.signup;
        _error = null;
      }),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.38)),
          children: [
            TextSpan(
                text: _mode == _Mode.signup
                    ? 'Already have an account?  '
                    : 'Don\'t have an account?  '),
            TextSpan(
                text: _mode == _Mode.signup ? 'Log In' : 'Sign Up',
                style: const TextStyle(
                    color: kGreen, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );

  Widget _resendRow() => Center(
    child: _countdown > 0
        ? RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35)),
              children: [
                const TextSpan(text: 'Resend OTP in  '),
                TextSpan(text: '${_countdown}s',
                    style: const TextStyle(
                        color: kGreen, fontWeight: FontWeight.w700)),
              ],
            ),
          )
        : GestureDetector(
            onTap: _loading ? null : _sendOtp,
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.38)),
                children: const [
                  TextSpan(text: 'Didn\'t receive it?  '),
                  TextSpan(text: 'Resend OTP',
                      style: TextStyle(
                          color: kGreen, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
  );

  Widget _termsNote() => Center(
    child: Text(
      'By continuing you agree to our Terms & Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2),
          height: 1.5),
    ),
  );
}