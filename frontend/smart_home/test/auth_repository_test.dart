import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';

import 'helpers/auth_test_data.dart';

void main() {
  test('dummy sign-in normalizes email while keeping password case-sensitive',
      () async {
    final repository = testAuthRepository();
    final user = await repository.signIn(
        email: '  ALEX@EXAMPLE.COM  ', password: dummyAuthPassword);
    expect(user.id, dummyAuthUser.id);
    expect(user.name, 'Alex');
    expect(await repository.restoreSession(), isNull);
    await expectLater(
        repository.signIn(
            email: dummyAuthUser.email,
            password: dummyAuthPassword.toLowerCase()),
        throwsA(isA<AuthException>()));
  });

  test('incorrect credentials cannot create or persist a session', () async {
    final preferences = MemoryAuthPreferences();
    final repository = AuthRepository(preferences: preferences);
    for (final credentials in [
      ('another@example.com', dummyAuthPassword),
      (dummyAuthUser.email, 'incorrect'),
      ('', ''),
    ]) {
      await expectLater(
          repository.signIn(
              email: credentials.$1,
              password: credentials.$2,
              rememberMe: true),
          throwsA(isA<AuthException>()));
    }
    expect(preferences.values, isEmpty);
  });

  test(
      'remembered sign-in survives a new repository without saving credentials',
      () async {
    final preferences = MemoryAuthPreferences();
    final repository = AuthRepository(preferences: preferences);
    await repository.signIn(
        email: dummyAuthUser.email,
        password: dummyAuthPassword,
        rememberMe: true);
    expect(preferences.values,
        {AuthRepository.rememberedUserKey: dummyAuthUser.id});
    final restarted = AuthRepository(preferences: preferences);
    expect((await restarted.restoreSession())?.email, dummyAuthUser.email);
    await restarted.signOut();
    expect(await repository.restoreSession(), isNull);
  });

  test('sign-in without Remember me removes a previous remembered session',
      () async {
    final preferences = MemoryAuthPreferences()
      ..values[AuthRepository.rememberedUserKey] = dummyAuthUser.id;
    final repository = AuthRepository(preferences: preferences);
    await repository.signIn(
        email: dummyAuthUser.email, password: dummyAuthPassword);
    expect(await repository.restoreSession(), isNull);
  });

  test(
      'unknown remembered users are rejected and sign-out preserves other settings',
      () async {
    final preferences = MemoryAuthPreferences()
      ..values[AuthRepository.rememberedUserKey] = 'unknown'
      ..values['another-setting'] = 'unchanged';
    final repository = AuthRepository(preferences: preferences);
    expect(await repository.restoreSession(), isNull);
    await repository.signOut();
    expect(preferences.values, {'another-setting': 'unchanged'});
  });
}
