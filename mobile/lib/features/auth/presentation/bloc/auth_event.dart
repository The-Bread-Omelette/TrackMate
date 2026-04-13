import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckSessionEvent extends AuthEvent {
  const AuthCheckSessionEvent();
}

class AuthLoginEvent extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginEvent({
    required this.email,
    required this.password
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final bool applyAsTrainer;

  const AuthRegisterEvent({
    required this.email,
    required this.password,
    required this.fullName,
    this.applyAsTrainer = false,
  });

  @override
  List<Object?> get props => [email, password, fullName, applyAsTrainer];
}

class AuthLogoutEvent extends AuthEvent {
  const AuthLogoutEvent();
}

class AuthResendVerificationEvent extends AuthEvent {
  final String email;
  const AuthResendVerificationEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthVerifyEmailEvent extends AuthEvent {
  final String email;
  final String otp;

  const AuthVerifyEmailEvent({required this.email, required this.otp});

  @override
  List<Object?> get props => [email, otp];
}
class AuthCompleteOnboardingEvent extends AuthEvent {
  const AuthCompleteOnboardingEvent();
}

class AuthForgotPasswordEvent extends AuthEvent {
  final String email;
  const AuthForgotPasswordEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthResetPasswordEvent extends AuthEvent {
  final String email;
  final String otp;
  final String newPassword;

  const AuthResetPasswordEvent({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [email, otp, newPassword];
}