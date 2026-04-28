import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';

const _kBaseUrl = 'https://fit24bc-production.up.railway.app';

class ApiService {
  final String token;
  ApiService(this.token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOtp(String phone, String mode) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'mode': mode}),
    );
    if (res.statusCode != 200) throw Exception('Failed to send OTP: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String token, String mode) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/auth/verify-otp'),
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
      Uri.parse('$_kBaseUrl/auth/refresh-token?refresh_token=$refreshToken'),
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
    final res = await http.post(
      Uri.parse('$_kBaseUrl/steps/sync'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('Failed to sync steps: ${res.body}');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getTodaySteps() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/steps/today'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch today steps');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getStepHistory({int days = 7}) async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/steps/history?days=$days'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch history');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getLeaderboard() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/steps/leaderboard'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch leaderboard');
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getSessions() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/steps/sessions'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch sessions');
    return jsonDecode(res.body);
  }

  Future<void> saveSession(Map<String, dynamic> session) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/steps/sessions'),
      headers: _headers,
      body: jsonEncode(session),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to save session');
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/profile/me'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch profile');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> setupProfile(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/profile/setup'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to setup profile: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$_kBaseUrl/profile/me'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Failed to update profile');
    return jsonDecode(res.body);
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getCategories() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/admin/categories'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch categories');
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getTutorials() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/admin/tutorials'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to fetch tutorials');
    return jsonDecode(res.body);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final token = ref.watch(accessTokenProvider);
  return ApiService(token);
});

