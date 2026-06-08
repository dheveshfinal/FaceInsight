// ==============================================================
//  FaceInsight – lib/core/providers/auth_store.dart
//  In-memory singleton for the current user's JWT tokens.
//  Cleared on page refresh (acceptable for dev; use
//  flutter_secure_storage for production persistence).
// ==============================================================

class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  String? _accessToken;
  String? _refreshToken;
  int?    _userId;

  // ── Write ─────────────────────────────────────────────────
  void save({
    required String accessToken,
    String? refreshToken,
    int? userId,
  }) {
    _accessToken  = accessToken;
    _refreshToken = refreshToken;
    _userId       = userId;
  }

  void clear() {
    _accessToken  = null;
    _refreshToken = null;
    _userId       = null;
  }

  // ── Read ──────────────────────────────────────────────────
  String? get accessToken  => _accessToken;
  String? get refreshToken => _refreshToken;
  int?    get userId       => _userId;
  bool   get isLoggedIn   => _accessToken != null;
}
