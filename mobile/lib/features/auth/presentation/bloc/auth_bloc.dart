import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(const AuthInitialState()) {
    on<AuthCheckSessionEvent>(_onCheckSession);
    on<AuthLoginEvent>(_onLogin);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthLogoutEvent>(_onLogout);
  }

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());
    final hasSession = await repository.hasStoredSession();
    if (!hasSession) {
      emit(const AuthUnauthenticatedState());
      return;
    }
    final result = await repository.getCurrentUser();
    result.fold(
      (failure) => emit(const AuthUnauthenticatedState()),
      (user) => emit(AuthAuthenticatedState(user)),
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
      role: event.role,
    );
    result.fold(
      (failure) => emit(AuthErrorState(failure.message)),
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
      role: event.role,
    );
    result.fold(
      (failure) => emit(AuthErrorState(failure.message)),
      (user) => emit(AuthAuthenticatedState(user)),
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
}
