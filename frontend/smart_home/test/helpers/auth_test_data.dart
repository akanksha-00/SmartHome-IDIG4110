import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';
import 'package:smart_home/src/models/authentication/auth_user.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';

/// Test-only authentication; the running app always uses Supabase.
class FakeAuthRepository extends AuthRepository {
  final sessions = StreamController<AuthUser?>.broadcast();
  AuthUser? user;

  @override
  Stream<AuthUser?> get sessionChanges => sessions.stream;

  @override
  String? get accessToken => user == null ? null : 'test-access-token';

  @override
  Future<AuthUser> signIn(
      {required String email, required String password}) async {
    if (email.trim().toLowerCase() != dummyAuthUser.email ||
        password != dummyAuthPassword) {
      throw const AuthException('The email or password is incorrect.');
    }
    user = dummyAuthUser;
    sessions.add(user);
    return user!;
  }

  @override
  Future<void> signOut() async {
    user = null;
    sessions.add(null);
  }

  Future<void> close() => sessions.close();
}

FakeAuthRepository testAuthRepository() {
  final repository = FakeAuthRepository();
  addTearDown(repository.close);
  return repository;
}

Future<void> signInAsDummyUser(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('auth-email')), dummyAuthUser.email);
  await tester.enterText(
      find.byKey(const ValueKey('auth-password')), dummyAuthPassword);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('auth-submit')));
  // Device loading can remain pending; don't settle an indeterminate spinner.
  await tester.pump();
  await tester.pump();
}
