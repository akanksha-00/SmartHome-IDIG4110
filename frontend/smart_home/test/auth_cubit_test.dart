import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';

import 'helpers/auth_test_data.dart';

class DelayedLogoutRepository extends FakeAuthRepository {
  final completion = Completer<void>();

  @override
  Future<void> signOut() async {
    await super.signOut();
    await completion.future;
  }
}

void main() {
  test('SDK session loss returns the Cubit to signed out', () async {
    final repository = testAuthRepository();
    final cubit = AuthCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.signIn(email: dummyAuthUser.email, password: dummyAuthPassword);
    final signedOut =
        cubit.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    repository.sessions.add(null);
    await signedOut;
    expect(cubit.state.user, isNull);
  });

  test('auth stream errors are handled without discarding the signed-in user',
      () async {
    final repository = testAuthRepository();
    final cubit = AuthCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.signIn(email: dummyAuthUser.email, password: dummyAuthPassword);
    final failedRefresh = cubit.stream.firstWhere((s) => s.error != null);
    repository.sessions.addError(StateError('Offline'));
    await failedRefresh;
    expect(cubit.state.user?.id, dummyAuthUser.id);
    expect(cubit.state.status, AuthStatus.signedIn);
  });

  test('an old logout response cannot sign out a newer login', () async {
    final repository = DelayedLogoutRepository();
    addTearDown(repository.close);
    final cubit = AuthCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.signIn(email: dummyAuthUser.email, password: dummyAuthPassword);
    final signedOut =
        cubit.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    final logout = cubit.signOut();
    await signedOut;
    await cubit.signIn(email: dummyAuthUser.email, password: dummyAuthPassword);
    repository.completion.complete();
    await logout;
    expect(cubit.state.status, AuthStatus.signedIn);
    expect(cubit.state.user?.id, dummyAuthUser.id);
  });
}
