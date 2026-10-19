import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

String testJwt(String marker) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({
        'sub': 'user-1',
        'exp': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'marker': marker,
      })}.test-signature';
}

Map<String, Object?> sessionJson(
        {String marker = 'first', bool withName = true}) =>
    {
      'access_token': testJwt(marker),
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'test-refresh-token',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'email': 'alex@example.com',
        'created_at': '2026-10-19T09:00:00Z',
        'app_metadata': {},
        'user_metadata': {if (withName) 'full_name': 'Alex'},
      },
    };

supabase.SupabaseClient mockSupabase(
    Future<http.Response> Function(http.Request) handler) {
  final client = supabase.SupabaseClient(
    'https://test.supabase.co',
    'sb_publishable_test',
    httpClient: MockClient(handler),
    authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  test(
      'Supabase signs in with email/password and exposes the real session token',
      () async {
    final response = sessionJson();
    final client = mockSupabase((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/token');
      expect(request.url.queryParameters['grant_type'], 'password');
      expect(request.headers['apikey'], 'sb_publishable_test');
      final body = jsonDecode(request.body) as Map;
      expect(body['email'], 'alex@example.com');
      expect(body['password'], 'CorrectPassword!');
      return http.Response(jsonEncode(response), 200);
    });
    final repository = AuthRepository(client: client);
    final user = await repository.signIn(
        email: ' ALEX@EXAMPLE.COM ', password: 'CorrectPassword!');
    expect(user.id, 'user-1');
    expect(user.name, 'Alex');
    expect(user.email, 'alex@example.com');
    expect(repository.accessToken, response['access_token']);
  });

  for (final (code, expected) in [
    ('invalid_credentials', 'The email or password is incorrect.'),
    ('email_not_confirmed', 'Confirm your email address before signing in.'),
  ]) {
    test('Supabase error $code cannot open a session', () async {
      final client = mockSupabase((_) async => http.Response(
          jsonEncode({'code': code, 'message': 'Authentication rejected'}), 400,
          headers: {'x-supabase-api-version': '2024-01-01'}));
      final repository = AuthRepository(client: client);
      await expectLater(
          repository.signIn(email: 'alex@example.com', password: 'incorrect'),
          throwsA(isA<AuthException>()
              .having((e) => e.message, 'message', expected)));
      expect(repository.accessToken, isNull);
    });
  }

  test('token refresh updates the token source and logout clears it locally',
      () async {
    var refresh = false;
    final client = mockSupabase((request) async {
      if (request.url.path.endsWith('/logout')) {
        expect(request.url.queryParameters['scope'], 'local');
        return http.Response('', 204);
      }
      refresh = request.url.queryParameters['grant_type'] == 'refresh_token';
      return http.Response(
          jsonEncode(sessionJson(marker: refresh ? 'refreshed' : 'first')),
          200);
    });
    final repository = AuthRepository(client: client);
    await repository.signIn(email: 'alex@example.com', password: 'password');
    final oldToken = repository.accessToken;
    await client.auth.refreshSession();
    expect(refresh, isTrue);
    expect(repository.accessToken, isNot(oldToken));
    await repository.signOut();
    expect(repository.accessToken, isNull);
  });

  test('an offline server revocation cannot restore an already cleared session',
      () async {
    final client = mockSupabase((request) async =>
        request.url.path.endsWith('/logout')
            ? http.Response(jsonEncode({'message': 'Unavailable'}), 500)
            : http.Response(jsonEncode(sessionJson(withName: false)), 200));
    final repository = AuthRepository(client: client);
    final user = await repository.signIn(
        email: 'alex@example.com', password: 'password');
    expect(user.name, 'alex');
    await repository.signOut();
    expect(repository.accessToken, isNull);
  });

  test('missing configuration never falls back to dummy credentials', () async {
    final repository = AuthRepository();
    await expectLater(
        repository.signIn(email: 'alex@example.com', password: 'SmartHome123!'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains('not configured'))));
    expect(repository.accessToken, isNull);
  });
}
