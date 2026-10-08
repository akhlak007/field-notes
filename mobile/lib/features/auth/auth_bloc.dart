import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.error,
    this.submitting = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final int? userId;
  final String? email;
  final String? error;
  final bool submitting;

  AuthState copyWith({
    AuthStatus? status,
    int? userId,
    String? email,
    String? error,
    bool? submitting,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      error: clearError ? null : error ?? this.error,
      submitting: submitting ?? this.submitting,
    );
  }

  @override
  List<Object?> get props => [status, userId, email, error, submitting];
}

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  const RegisterRequested({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });
  final String email;
  final String password;
  final String confirmPassword;
  @override
  List<Object?> get props => [email, password, confirmPassword];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class SessionExpired extends AuthEvent {
  const SessionExpired();
}

class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<LoginRequested>(_onLogin);
    on<RegisterRequested>(_onRegister);
    on<LogoutRequested>(_onLogout);
    on<SessionExpired>(_onLogout);
    on<AuthErrorCleared>(_onErrorCleared);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final session = await _repository.current();
    if (session == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } else {
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          userId: session.userId,
          email: session.email,
        ),
      );
    }
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    final email = event.email.trim();
    if (email.isEmpty || !email.contains('@')) {
      emit(state.copyWith(error: 'Enter a valid email.', submitting: false));
      return;
    }
    if (event.password.isEmpty) {
      emit(state.copyWith(error: 'Password is required.', submitting: false));
      return;
    }
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final session = await _repository.login(
        email: email,
        password: event.password,
      );
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          userId: session.userId,
          email: session.email,
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          submitting: false,
          error: apiErrorMessage(error, fallback: 'Could not sign in.'),
        ),
      );
    }
  }

  Future<void> _onRegister(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    if (email.isEmpty || !email.contains('@')) {
      emit(state.copyWith(error: 'Enter a valid email.', submitting: false));
      return;
    }
    if (event.password.length < 8) {
      emit(
        state.copyWith(
          error: 'Password must be at least 8 characters.',
          submitting: false,
        ),
      );
      return;
    }
    if (event.password != event.confirmPassword) {
      emit(state.copyWith(error: 'Passwords do not match.', submitting: false));
      return;
    }
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final session = await _repository.registerAndLogin(
        email: email,
        password: event.password,
      );
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          userId: session.userId,
          email: session.email,
        ),
      );
    } on DioException catch (error) {
      emit(
        state.copyWith(
          submitting: false,
          error: apiErrorMessage(
            error,
            fallback: 'Could not create the account.',
          ),
        ),
      );
    }
  }

  Future<void> _onLogout(AuthEvent event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
