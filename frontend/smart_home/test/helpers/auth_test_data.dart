import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';

class MemoryAuthPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

AuthRepository testAuthRepository({bool remembered = false}) {
  final preferences = MemoryAuthPreferences();
  if (remembered) {
    preferences.values[AuthRepository.rememberedUserKey] = dummyAuthUser.id;
  }
  return AuthRepository(preferences: preferences);
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
