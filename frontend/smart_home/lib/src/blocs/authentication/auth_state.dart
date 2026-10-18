import 'package:smart_home/src/models/authentication/auth_user.dart';

enum AuthStatus { restoring, signedOut, signingIn, signedIn, signingOut }

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  bool get isBusy =>
      status == AuthStatus.restoring ||
      status == AuthStatus.signingIn ||
      status == AuthStatus.signingOut;
}
