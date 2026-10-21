/// Signed-in identity. Credentials are kept out of the app's user state.
class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}
