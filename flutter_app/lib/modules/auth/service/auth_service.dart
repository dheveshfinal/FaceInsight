// ==============================================================
//  FaceInsight – lib/modules/auth/service/auth_service.dart
//  HTTP calls: login, register, logout
//  Saves tokens to AuthStore after successful auth.
// ==============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_store.dart';
import '../types/auth_types.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Headers ───────────────────────────────────────────────
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  // ── Login ─────────────────────────────────────────────────
  Future<AuthResponse> login(LoginRequest req) async {
    final res = await http.post(
      Uri.parse(AppConstants.loginUrl),
      headers: _jsonHeaders,
      body: jsonEncode(req.toJson()),
    );
    _assertOk(res);
    final data = AuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);

    // ── Save token so other services can use it immediately ──
    AuthStore.instance.save(
      accessToken:  data.accessToken,
      refreshToken: data.refreshToken,
      userId:       data.userId,
    );
    return data;
  }

  // ── Register ──────────────────────────────────────────────
  Future<AuthResponse> register(RegisterRequest req) async {
    final res = await http.post(
      Uri.parse(AppConstants.registerUrl),
      headers: _jsonHeaders,
      body: jsonEncode(req.toJson()),
    );
    _assertOk(res);
    final data = AuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);

    // ── Save token immediately after registration ─────────
    AuthStore.instance.save(
      accessToken:  data.accessToken,
      refreshToken: data.refreshToken,
      userId:       data.userId,
    );
    return data;
  }

  // ── Login As Guest ─────────────────────────────────────────
  Future<AuthResponse> loginAsGuest() async {
    final res = await http.post(
      Uri.parse(AppConstants.registerUrl.replaceAll("/register", "/guest")),
      headers: _jsonHeaders,
    );
    _assertOk(res);
    final data = AuthResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);

    AuthStore.instance.save(
      accessToken:  data.accessToken,
      refreshToken: data.refreshToken,
      userId:       data.userId,
    );
    return data;
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    final token = AuthStore.instance.accessToken;
    if (token != null) {
      await http.post(
        Uri.parse(AppConstants.logoutUrl),
        headers: {
          ..._jsonHeaders,
          'Authorization': 'Bearer $token',
        },
      );
    }
    AuthStore.instance.clear();
  }

  // ── Helper ────────────────────────────────────────────────
  void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw AuthError(
        message:    body['detail'] as String? ??
                    body['error']  as String? ?? 'Unknown error',
        statusCode: res.statusCode,
      );
    }
  }
}