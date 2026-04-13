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


class RegisterResponseModel {
  final String message;
  const RegisterResponseModel({required this.message});
  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) =>
      RegisterResponseModel(message: json['message'] as String);
}