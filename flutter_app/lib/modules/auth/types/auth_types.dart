// ==============================================================
//  FaceInsight – lib/modules/auth/types/auth_types.dart
//  Data models for login / register requests & responses
// ==============================================================

class LoginRequest {
  final String email;
  final String password;
  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class RegisterRequest {
  final String email;
  final String password;
  const RegisterRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String email;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken:  json['access_token']  as String,
        refreshToken: json['refresh_token'] as String,
        userId:       json['user_id']       as int,
        email:        json['email']         as String,
      );
}

class AuthError {
  final String message;
  final int statusCode;
  const AuthError({required this.message, required this.statusCode});
}