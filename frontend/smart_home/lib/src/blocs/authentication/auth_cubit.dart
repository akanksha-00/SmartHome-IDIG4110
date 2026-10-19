import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_state.dart';
import 'package:smart_home/src/models/authentication/auth_user.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';

export 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this.repository})
      : super(const AuthState(status: AuthStatus.signedOut)) {
    _sessionSubscription = repository.sessionChanges.listen(
      _sessionChanged,
      onError: (Object error, StackTrace stackTrace) {
        if (!isClosed && state.user != null && !state.isBusy) {
          emit(AuthState(
              status: AuthStatus.signedIn,
              user: state.user,
              error: 'Could not refresh your sign-in. Check your connection.'));
        }
      },
    );
  }

  final AuthRepository repository;
  late final StreamSubscription<AuthUser?> _sessionSubscription;
  int _operation = 0;

  void _sessionChanged(AuthUser? user) {
    if (isClosed) return;
    if (user == null && state.user != null) {
      ++_operation;
      emit(const AuthState(status: AuthStatus.signedOut));
    } else if (user != null && state.user != null && !state.isBusy) {
      final previous = state.user!;
      if (previous.id != user.id ||
          previous.name != user.name ||
          previous.email != user.email ||
          state.error != null) {
        emit(AuthState(status: AuthStatus.signedIn, user: user));
      }
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (state.isBusy || state.user != null) return;
    final operation = ++_operation;
    emit(const AuthState(status: AuthStatus.signingIn));
    try {
      final user = await repository.signIn(email: email, password: password);
      if (!isClosed && operation == _operation) {
        emit(AuthState(status: AuthStatus.signedIn, user: user));
      }
    } on AuthException catch (error) {
      if (!isClosed && operation == _operation) {
        emit(AuthState(status: AuthStatus.signedOut, error: error.message));
      }
    } catch (_) {
      if (!isClosed && operation == _operation) {
        emit(const AuthState(
            status: AuthStatus.signedOut,
            error: 'Could not sign in. Please try again.'));
      }
    }
  }

  Future<void> signOut() async {
    final user = state.user;
    if (user == null || state.isBusy) return;
    final operation = ++_operation;
    emit(AuthState(status: AuthStatus.signingOut, user: user));
    try {
      await repository.signOut();
      if (!isClosed && operation == _operation) {
        emit(const AuthState(status: AuthStatus.signedOut));
      }
    } catch (_) {
      if (!isClosed && operation == _operation) {
        emit(AuthState(
            status: AuthStatus.signedIn,
            user: user,
            error: 'Could not sign out. Please try again.'));
      }
    }
  }

  void clearError() {
    if (state.error != null) {
      emit(AuthState(status: state.status, user: state.user));
    }
  }

  @override
  Future<void> close() async {
    ++_operation;
    await _sessionSubscription.cancel();
    await super.close();
  }
}
