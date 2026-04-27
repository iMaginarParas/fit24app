// auth_state.dart
// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers for authentication state.
// Persists access_token, refresh_token, user_id, and phone to SharedPreferences
// so the user stays logged in across app restarts.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ─────────────────────────────────────────────────────────────────────
const _kAccessToken  = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kUserId       = 'auth_user_id';
const _kPhone        = 'auth_phone';

// ── Model ─────────────────────────────────────────────────────────────────────
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String phone;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.phone,
  });

  bool get isValid => accessToken.isNotEmpty && userId.isNotEmpty;
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<AuthSession?> {

  @override
  Future<AuthSession?> build() async {
    // Load persisted session on app start
    final prefs = await SharedPreferences.getInstance();
    final token  = prefs.getString(_kAccessToken)  ?? '';
    final refresh= prefs.getString(_kRefreshToken) ?? '';
    final uid    = prefs.getString(_kUserId)        ?? '';
    final phone  = prefs.getString(_kPhone)         ?? '';
    if (token.isEmpty || uid.isEmpty) return null;
    return AuthSession(
      accessToken:  token,
      refreshToken: refresh,
      userId:       uid,
      phone:        phone,
    );
  }

  Future<void> signIn({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken,  accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
    await prefs.setString(_kUserId,       userId);
    await prefs.setString(_kPhone,        phone);
    state = AsyncData(AuthSession(
      accessToken:  accessToken,
      refreshToken: refreshToken,
      userId:       userId,
      phone:        phone,
    ));
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kPhone);
    state = const AsyncData(null);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
);

/// Convenience: just the access token (or empty string)
final accessTokenProvider = Provider<String>((ref) {
  return ref.watch(authProvider).valueOrNull?.accessToken ?? '';
});

/// Convenience: current user id (or empty string)
final userIdProvider = Provider<String>((ref) {
  return ref.watch(authProvider).valueOrNull?.userId ?? '';
});