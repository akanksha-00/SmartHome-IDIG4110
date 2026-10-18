import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';
import 'package:smart_home/src/models/authentication/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

/// Local demo implementation. Replace these methods with the authentication
/// API later, keeping the screen and Cubit independent of the transport.
class AuthRepository {
  AuthRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences;

  static const rememberedUserKey = 'smart_home.demo_auth.remembered_user';
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  Future<AuthUser?> restoreSession() async {
    final id = await _store.getString(rememberedUserKey);
    if (id == dummyAuthUser.id) return dummyAuthUser;
    if (id != null) await _store.remove(rememberedUserKey);
    return null;
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (email.trim().toLowerCase() != dummyAuthUser.email ||
        password != dummyAuthPassword) {
      throw const AuthException('The email or password is incorrect.');
    }
    // Only a demo user ID is persisted. Never store the password.
    if (rememberMe) {
      await _store.setString(rememberedUserKey, dummyAuthUser.id);
    } else {
      await _store.remove(rememberedUserKey);
    }
    return dummyAuthUser;
  }

  Future<void> signOut() => _store.remove(rememberedUserKey);
}
