import 'package:bloc/bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_state.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';

export 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this.repository})
      : super(const AuthState(status: AuthStatus.signedOut));

  final AuthRepository repository;

  Future<void> restoreSession() async {
    if (state.isBusy || state.user != null) return;
    emit(const AuthState(status: AuthStatus.restoring));
    try {
      final user = await repository.restoreSession();
      if (isClosed) return;
      emit(AuthState(
          status: user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
          user: user));
    } catch (_) {
      if (!isClosed) {
        emit(const AuthState(status: AuthStatus.signedOut));
      }
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (state.isBusy || state.user != null) return;
    emit(const AuthState(status: AuthStatus.signingIn));
    try {
      final user = await repository.signIn(
          email: email, password: password, rememberMe: rememberMe);
      if (!isClosed) {
        emit(AuthState(status: AuthStatus.signedIn, user: user));
      }
    } on AuthException catch (error) {
      if (!isClosed) {
        emit(AuthState(status: AuthStatus.signedOut, error: error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(const AuthState(
            status: AuthStatus.signedOut,
            error: 'Could not sign in. Please try again.'));
      }
    }
  }

  Future<void> signOut() async {
    final user = state.user;
    if (user == null || state.isBusy) return;
    emit(AuthState(status: AuthStatus.signingOut, user: user));
    try {
      await repository.signOut();
      if (!isClosed) {
        emit(const AuthState(status: AuthStatus.signedOut));
      }
    } catch (_) {
      if (!isClosed) {
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
}
