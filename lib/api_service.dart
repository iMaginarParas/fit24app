import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';

const kBaseUrl = 'https://fit24bc-production.up.railway.app';

class ApiService {
  final String token;
  final Ref ref;
  ApiService(this.token, this.ref);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // Wrapper for all authenticated requests to handle token expiration (401)
  Future<http.Response> _req(Future<http.Response> Function() call) async {
    final res = await call();
    if (res.statusCode == 401) {
      final auth = ref.read(authProvider).valueOrNull;
      if (auth != null && auth.refreshToken.isNotEmpty) {
        try {
          // Attempt refresh
          final refreshRes = await http.post(
            Uri.parse('$kBaseUrl/auth/refresh-token?refresh_token=${auth.refreshToken}'),
          );
          if (refreshRes.statusCode == 200) {
            final data = jsonDecode(refreshRes.body);
            await ref.read(authProvider.notifier).signIn(
              accessToken: data['access_token'],
              refreshToken: data['refresh_token'] ?? auth.refreshToken,
              userId: auth.userId,
              phone: auth.phone,
            );
            // Retry the original request with new token
            return await call();
          }
        } catch (_) {}
      }
      // If refresh fails, log out
      ref.read(authProvider.notifier).signOut();
    }
    return res;
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOtp(String phone, String mode) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'mode': mode}),
    );
    if (res.statusCode != 200) throw Exception('Failed to send OTP: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String token, String mode) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'token': token,
        'mode': mode,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to verify OTP: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/refresh-token?refresh_token=$refreshToken'),
    );
    if (res.statusCode != 200) throw Exception('Failed to refresh token');
    return jsonDecode(res.body);
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> syncSteps(int steps, {DateTime? date}) async {
    final body = {
      'steps': steps,
      if (date != null) 'log_date': date.toIso8601String().split('T')[0],
    };
    final res = await _req(() => http.post(
      Uri.parse('$kBaseUrl/steps/sync'),
      headers: _headers,
      body: jsonEncode(body),
    ));
    if (res.statusCode != 200) throw Exception('Failed to sync steps: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getTodaySteps() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/steps/today'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch today steps');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getStepHistory({int days = 7}) async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/steps/history?days=$days'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch history');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getStats() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/steps/stats'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch stats');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getLeaderboard() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/steps/leaderboard'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch leaderboard');
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getSessions() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/steps/sessions'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch sessions');
    return jsonDecode(res.body);
  }

  Future<void> saveSession(Map<String, dynamic> session) async {
    final res = await _req(() => http.post(
      Uri.parse('$kBaseUrl/steps/sessions'),
      headers: _headers,
      body: jsonEncode(session),
    ));
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to save session');
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/profile/me'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch profile');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> setupProfile(Map<String, dynamic> data) async {
    final res = await _req(() => http.post(
      Uri.parse('$kBaseUrl/profile/setup'),
      headers: _headers,
      body: jsonEncode(data),
    ));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to setup profile: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _req(() => http.patch(
      Uri.parse('$kBaseUrl/profile/me'),
      headers: _headers,
      body: jsonEncode(data),
    ));
    if (res.statusCode != 200) throw Exception('Failed to update profile');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/profile/me/avatar'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    
    if (res.statusCode != 200) throw Exception('Failed to upload avatar: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<void> deleteAccount() async {
    final res = await _req(() => http.delete(
      Uri.parse('$kBaseUrl/profile/me'),
      headers: _headers,
    ));
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete account');
    }
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getCategories() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/admin/categories'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch categories');
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getTutorials() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/admin/tutorials'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch tutorials');
    return jsonDecode(res.body);
  }

  // ── Config ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getKeys() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/config/keys'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('Failed to fetch keys');
    return jsonDecode(res.body);
  }

  // ── Challenges ─────────────────────────────────────────────────────────────
  
  Future<List<dynamic>> getChallenges() async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/challenges/'),
      headers: _headers,
    ));
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> claimChallenge(String id) async {
    final res = await _req(() => http.post(
      Uri.parse('$kBaseUrl/challenges/claim/$id'),
      headers: _headers,
    ));
    return jsonDecode(res.body);
  }

  // ── Social ─────────────────────────────────────────────────────────────────
  
  Future<void> followUser(String id) async {
    final res = await _req(() => http.post(
      Uri.parse('$kBaseUrl/profile/follow/$id'),
      headers: _headers,
    ));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to follow');
    }
  }

  Future<void> unfollowUser(String id) async {
    final res = await _req(() => http.delete(
      Uri.parse('$kBaseUrl/profile/follow/$id'),
      headers: _headers,
    ));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to unfollow');
    }
  }

  Future<Map<String, dynamic>> getPublicProfile(String id) async {
    final res = await _req(() => http.get(
      Uri.parse('$kBaseUrl/profile/public/$id'),
      headers: _headers,
    ));
    if (res.statusCode != 200) throw Exception('User not found');
    return jsonDecode(res.body);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final token = ref.watch(accessTokenProvider);
  return ApiService(token, ref);
});

