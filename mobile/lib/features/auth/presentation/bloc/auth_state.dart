import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {
  const AuthInitialState();
}

class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}

class AuthAuthenticatedState extends AuthState {
  final UserEntity user;

  const AuthAuthenticatedState(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticatedState extends AuthState {
  const AuthUnauthenticatedState();
}
class AuthErrorState extends AuthState {
  final String message;

  const AuthErrorState(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthVerificationSentState extends AuthState {
  const AuthVerificationSentState();
}
class AuthRegisteredState extends AuthState {
  final String email;
  const AuthRegisteredState({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthUnverifiedState extends AuthState {
  final String email;
  const AuthUnverifiedState({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthOnboardingState extends AuthState {
  const AuthOnboardingState();
}

class AuthPasswordResetEmailSentState extends AuthState {
  final String email;
  const AuthPasswordResetEmailSentState({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthPasswordResetSuccessState extends AuthState {
  const AuthPasswordResetSuccessState();
}