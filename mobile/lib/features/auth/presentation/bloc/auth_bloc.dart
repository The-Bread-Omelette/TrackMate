import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../../core/errors/failures.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(const AuthInitialState()) {
    on<AuthCheckSessionEvent>(_onCheckSession);
    on<AuthLoginEvent>(_onLogin);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthLogoutEvent>(_onLogout);
    on<AuthResendVerificationEvent>(_onResendVerification);
    on<AuthVerifyEmailEvent>(_onVerifyEmail);
    on<AuthCompleteOnboardingEvent>(_onCompleteOnboarding);
  }

  Future<void> _onVerifyEmail(
    AuthVerifyEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await repository.verifyEmail(
      email: event.email,
      otp: event.otp,
    );
    result.fold(
      (failure) {
        emit(AuthErrorState(failure.message));
        emit(AuthUnverifiedState(email: event.email));
      },
      (user) => emit(const AuthOnboardingState()),
    );
  }

  Future<void> _onCompleteOnboarding(
    AuthCompleteOnboardingEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState()); // Let UI know we are checking session
    final result = await repository.getCurrentUser();
    result.fold(
      (failure) {
        emit(AuthErrorState(failure.message)); // Emit error if it fails
        emit(const AuthUnauthenticatedState());
      },
      (user) => emit(AuthAuthenticatedState(user)), // Triggers the router redirect!
    );
  }

  Future<void> _onLogin(
    AuthLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await repository.login(
      email: event.email,
      password: event.password,
    );
    result.fold(
      (failure) {
        if (failure is ForbiddenFailure &&
            failure.message.toLowerCase().contains('verify')) {
          emit(AuthUnverifiedState(email: event.email));
          repository.resendVerification(email: event.email);
        } else {
          emit(AuthErrorState(failure.message));
          emit(const AuthUnauthenticatedState());
        }
      },
      (user) => emit(AuthAuthenticatedState(user)),
    );
  }

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await repository.getCurrentUser();
    result.fold(
      (failure) => emit(const AuthUnauthenticatedState()),
      (user) => emit(AuthAuthenticatedState(user)),
    );
  }

  Future<void> _onRegister(
    AuthRegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await repository.register(
      email: event.email,
      password: event.password,
      fullName: event.fullName,
      applyAsTrainer: event.applyAsTrainer,
    );
    result.fold(
      (failure) {
        emit(AuthErrorState(failure.message));
        emit(const AuthUnauthenticatedState());
      },
      (_) => emit(AuthRegisteredState(email: event.email)),
    );
  }

  Future<void> _onLogout(
    AuthLogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    await repository.logout();
    emit(const AuthUnauthenticatedState());
  }

  Future<void> _onResendVerification(
    AuthResendVerificationEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final result = await repository.resendVerification(email: event.email);
    result.fold(
      (failure) {
        emit(AuthErrorState(failure.message));
        emit(AuthRegisteredState(email: event.email));
      },
      (_) => emit(AuthRegisteredState(email: event.email)),
    );
  }
}