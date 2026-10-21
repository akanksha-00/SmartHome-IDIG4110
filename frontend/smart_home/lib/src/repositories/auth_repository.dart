import 'package:smart_home/src/models/authentication/auth_user.dart';
import 'package:smart_home/src/logging/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

/// Supabase credentials and sessions stay in the SDK, outside app/BLoC state.
class AuthRepository {
  AuthRepository({supabase.SupabaseClient? client, this.configurationError})
      : _client = client;

  final supabase.SupabaseClient? _client;
  final String? configurationError;

  String? get accessToken => _client?.auth.currentSession?.accessToken;

  Stream<AuthUser?> get sessionChanges =>
      _client?.auth.onAuthStateChange.map((event) {
        final user = event.session?.user;
        return user == null ? null : _user(user);
      }) ??
      const Stream<AuthUser?>.empty();

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw AuthException(
          configurationError ?? 'Sign-in is not configured for this app.');
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (response.session == null || user == null) {
        throw const AuthException(
            'Sign-in did not create a session. Try again.');
      }
      return _user(user);
    } on supabase.AuthException catch (error) {
      throw AuthException(switch (error.code) {
        'invalid_credentials' => 'The email or password is incorrect.',
        'email_not_confirmed' =>
          'Confirm your email address before signing in.',
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' =>
          'Too many attempts. Please try again later.',
        _ => error.message,
      });
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.auth.signOut(scope: supabase.SignOutScope.local);
    } catch (error, stackTrace) {
      // The SDK clears the local session before requesting server revocation.
      // A network failure must not restore a user whose token is already gone.
      if (client.auth.currentSession != null) rethrow;
      AppLog.warning('Auth',
          'Local sign-out completed, but remote token revocation failed',
          error: error, stackTrace: stackTrace);
    }
  }

  AuthUser _user(supabase.User user) {
    final email = user.email ?? '';
    final metadataName =
        user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
    final name = metadataName is String && metadataName.trim().isNotEmpty
        ? metadataName.trim()
        : email.isNotEmpty
            ? email.split('@').first
            : 'Home user';
    return AuthUser(id: user.id, name: name, email: email);
  }
}
