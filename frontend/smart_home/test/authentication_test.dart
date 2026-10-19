import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/main.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/dummyData/auth_data.dart';
import 'package:smart_home/src/models/authentication/auth_user.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:smart_home/src/screen/authentication/authentication_gate.dart';
import 'package:smart_home/src/theme/app_theme.dart';

import 'helpers/auth_test_data.dart';
import 'helpers/device_test_data.dart';

Widget authHarness(AuthRepository repository) => BlocProvider(
      create: (_) => AuthCubit(repository: repository),
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: AuthenticationGate(
            signedInBuilder: (context, user) => Scaffold(
                  body: Column(children: [
                    Text('Signed in as ${user.name}'),
                    TextButton(
                        onPressed: () => context.read<AuthCubit>().signOut(),
                        child: const Text('Sign out')),
                  ]),
                )),
      ),
    );

class PendingAuthRepository extends AuthRepository {
  PendingAuthRepository() : super(preferences: MemoryAuthPreferences());
  final response = Completer<AuthUser>();
  int calls = 0;
  @override
  Future<AuthUser> signIn(
      {required String email,
      required String password,
      bool rememberMe = false}) {
    calls++;
    return response.future;
  }
}

Future<void> openAuth(WidgetTester tester, AuthRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(authHarness(repository));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validation, rejected credentials and retry work without an API',
      (tester) async {
    await openAuth(tester, testAuthRepository());
    final submit = find.byKey(const ValueKey('auth-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('auth-email')), 'invalid');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('auth-email')), dummyAuthUser.email);
    await tester.enterText(
        find.byKey(const ValueKey('auth-password')), 'incorrect');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    await signInAsDummyUser(tester);
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Alex'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('auth-password')))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('password visibility preserves the typed password',
      (tester) async {
    await openAuth(tester, testAuthRepository());
    final password = find.byKey(const ValueKey('auth-password'));
    await tester.enterText(password, dummyAuthPassword);
    expect(tester.widget<TextFormField>(password).controller!.text,
        dummyAuthPassword);
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)))
            .obscureText,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('auth-password-visibility')));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)))
            .obscureText,
        isFalse);
  });

  testWidgets(
      'sign-in is required on launch and again after restarting the app',
      (tester) async {
    final preferences = MemoryAuthPreferences()
      ..values[AuthRepository.rememberedUserKey] = dummyAuthUser.id;
    await openAuth(tester, AuthRepository(preferences: preferences));
    expect(find.text('Welcome back'), findsOneWidget);
    await signInAsDummyUser(tester);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester
        .pumpWidget(authHarness(AuthRepository(preferences: preferences)));
    await tester.pumpAndSettle();
    expect(preferences.values, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign-in stays busy and ignores repeated submissions',
      (tester) async {
    final repository = PendingAuthRepository();
    await openAuth(tester, repository);
    await signInAsDummyUser(tester);
    expect(repository.calls, 1);
    expect(find.text('Signing in…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull);
    tester
        .element(find.byKey(const ValueKey('auth-submit')))
        .read<AuthCubit>()
        .signIn(email: dummyAuthUser.email, password: dummyAuthPassword);
    await tester.pump();
    expect(repository.calls, 1);
    repository.response.complete(dummyAuthUser);
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Alex'), findsOneWidget);
  });

  for (final size in [
    const Size(1440, 1000),
    const Size(390, 844),
    const Size(320, 600),
    const Size(1100, 540)
  ]) {
    testWidgets('sign-in fits ${size.width} x ${size.height}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(authHarness(testAuthRepository()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-brand-panel')),
          size.width >= 1000 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await signInAsDummyUser(tester);
      await tester.pumpAndSettle();
      expect(find.text('Signed in as Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final logoutLocation in ['Settings', 'sidebar']) {
    testWidgets(
        'MyApp fetches no house data until sign-in and $logoutLocation signs out',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      final source = testDeviceBloc((_) async {
        calls++;
        return jsonResponse([]);
      });
      await tester.pumpWidget(MyApp(
          authRepository: testAuthRepository(),
          deviceRepository: source.repository));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(calls, 0);
      await signInAsDummyUser(tester);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Welcome, Alex'), findsOneWidget);
      if (logoutLocation == 'sidebar') {
        await tester.tap(find.byTooltip('Notifications'));
        await tester.pumpAndSettle();
        expect(find.text('3 unread'), findsOneWidget);
        await tester.tap(find.text('Mark all as read'));
        await tester.pumpAndSettle();
        expect(find.text('0 unread'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(calls, 2);
      }
      if (logoutLocation == 'Settings') {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }
      final signOut = find.byKey(ValueKey(logoutLocation == 'Settings'
          ? 'settings-row-sign-out'
          : 'sidebar-logout'));
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(calls, 2);
      await signInAsDummyUser(tester);
      await tester.pumpAndSettle();
      expect(calls, 4);
      if (logoutLocation == 'sidebar') {
        await tester.tap(find.byTooltip('Notifications'));
        await tester.pumpAndSettle();
        expect(find.text('3 unread'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('sign-out works while house requests are still pending',
      (tester) async {
    final response = Completer<http.Response>();
    final source = testDeviceBloc((_) => response.future);
    await tester.pumpWidget(MyApp(
        authRepository: testAuthRepository(),
        deviceRepository: source.repository));
    await signInAsDummyUser(tester);
    expect(find.text('Loading devices…'), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    response.complete(jsonResponse([]));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
