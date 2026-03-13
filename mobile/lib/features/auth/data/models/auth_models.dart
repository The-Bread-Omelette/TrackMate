class TokenModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const TokenModel({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) => TokenModel(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
      );
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isVerified;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        isVerified: json['is_verified'] as bool,
      );
}

class AuthResponseModel {
  final UserModel user;
  final TokenModel tokens;

  const AuthResponseModel({required this.user, required this.tokens});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) => AuthResponseModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        tokens: TokenModel.fromJson(json['tokens'] as Map<String, dynamic>),
      );
}
