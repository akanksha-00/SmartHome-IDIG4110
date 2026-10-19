import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/screen/authentication/authentication_gate.dart';
import 'package:smart_home/src/services/web_socket_service.dart';
import 'package:smart_home/src/theme/app_theme.dart';
import 'package:smart_home/src/widgets/house_access_gate.dart';

import 'helpers/auth_test_data.dart';
import 'helpers/device_test_data.dart' show jsonResponse;
import 'helpers/fake_web_socket.dart';

Future<void> openHouseGate(WidgetTester tester,
    Future<http.Response> Function(http.Request) handler) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = testAuthRepository();
  final settings = AppSettingsController();
  addTearDown(settings.dispose);
  final api = ApiClient(
      client: MockClient(handler), accessToken: () => auth.accessToken);
  addTearDown(api.close);
  final realtime = HouseRealtimeRepository(
      socket: WebSocketService(
          endpoint: 'ws://example.test/ws', connector: (_) => FakeChannel()));
  await tester.pumpWidget(AppSettingsScope(
    controller: settings,
    child: RepositoryProvider<AuthRepository>.value(
      value: auth,
      child: BlocProvider(
        create: (_) => AuthCubit(repository: auth),
        child: MaterialApp(
            theme: AppTheme.dark(),
            home: AuthenticationGate(
              signedInBuilder: (_, user) => HouseAccessGate(
                  key: ValueKey(user.id), apiClient: api, realtime: realtime),
            )),
      ),
    ),
  ));
  await signInAsDummyUser(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads only the backend-authorized house using the user token',
      (tester) async {
    final paths = <String>[];
    await openHouseGate(tester, (request) async {
      expect(request.headers['authorization'], 'Bearer test-access-token');
      paths.add(request.url.path);
      return jsonResponse(request.url.path == '/api/v1/houses'
          ? [
              {'id': 'house-for-user'}
            ]
          : []);
    });
    expect(paths.first, '/api/v1/houses');
    expect(paths, contains('/api/v1/houses/house-for-user/devices'));
    expect(paths, contains('/api/v1/houses/house-for-user/rooms'));
    expect(paths.any((path) => path.contains('house-001')), isFalse);
    expect(find.text('Welcome, Alex'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (response, text) in [
    (jsonResponse([]), 'No house is assigned to your account.'),
    (jsonResponse([{}]), 'Could not load your houses.'),
    (http.Response('Unavailable', 503), 'Could not load your houses.'),
  ]) {
    testWidgets(
        '$text never falls back to a hardcoded house (${response.body})',
        (tester) async {
      var calls = 0;
      await openHouseGate(tester, (request) async {
        calls++;
        expect(request.url.path, '/api/v1/houses');
        return calls == 1 ? response : jsonResponse([]);
      });
      expect(find.text(text), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
          find.text('No house is assigned to your account.'), findsOneWidget);
      expect(calls, 2);
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
