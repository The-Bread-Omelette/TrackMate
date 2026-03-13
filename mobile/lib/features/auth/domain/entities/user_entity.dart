import 'package:equatable/equatable.dart';

enum UserRole { trainee, trainer, admin }

UserRole roleFromString(String value) {
  switch (value) {
    case 'trainer':
      return UserRole.trainer;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.trainee;
  }
}

String roleToString(UserRole role) => role.name;

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final bool isVerified;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isVerified,
  });

  @override
  List<Object?> get props => [id, email, fullName, role, isActive, isVerified];
}
