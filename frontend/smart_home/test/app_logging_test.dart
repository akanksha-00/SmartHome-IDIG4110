import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/logging/app_error_handlers.dart';
import 'package:smart_home/src/logging/app_log.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

import 'helpers/device_test_data.dart';
import 'helpers/fake_web_socket.dart';

class _TestCubit extends Cubit<int> {
  _TestCubit() : super(0);

  void reportFailure(Object error, StackTrace stackTrace) =>
      addError(error, stackTrace);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> lines;
  late DebugPrintCallback previousPrint;

  setUp(() {
    lines = [];
    previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  });
  tearDown(() => debugPrint = previousPrint);

  test('console entries carry severity/time and omit raw exception contents',
      () {
    AppLog.info('Test', 'Connected');
    AppLog.warning('Test', 'Connection interrupted');
    AppLog.error('Test', 'Operation failed',
        error: StateError('Bearer private-token password=private-password'),
        stackTrace: StackTrace.current);
    final output = lines.join('\n');
    expect(output, contains('[SmartHome]'));
    expect(output, matches(RegExp(r'\[\d{4}-\d{2}-\d{2}T[^\]]+Z\]')));
    expect(output, contains('[INFO][Test]'));
    expect(output, contains('[WARN][Test]'));
    expect(output, contains('[ERROR][Test]'));
    expect(output, contains('error=StateError'));
    expect(output, contains('stack'));
    expect(output, isNot(contains('private-token')));
    expect(output, isNot(contains('private-password')));
    expect(
        AppLog.endpoint(
            'https://user:password@api.example:8001/api/devices?token=secret#secret'),
        'https://api.example:8001/api/devices');
    expect(AppLog.endpoint(null), '(unconfigured endpoint)');
    expect(
        () => AppLog.error('Test', 'Stream error',
            stackTrace: StackTrace.fromString(
                '===== asynchronous gap ===========================\n#0 test')),
        returnsNormally);
  });

  test('all HTTP methods retain their results and log no headers/body/query',
      () async {
    final api = ApiClient(
      accessToken: () => 'private-access-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer private-access-token');
        return ['GET', 'POST'].contains(request.method)
            ? http.Response('{"result":"private-response"}', 200)
            : http.Response('', 204);
      }),
    );
    addTearDown(api.close);
    const url = 'https://api.example/api/devices?token=private-query';
    expect(await api.get(url), {'result': 'private-response'});
    expect(await api.post(url, {'password': 'private-body'}),
        {'result': 'private-response'});
    expect(await api.patch(url, {'state': 'private-body'}), isNull);
    expect(await api.put(url, {'state': 'private-body'}), isNull);
    expect(await api.delete(url), isNull);
    final output = lines.join('\n');
    for (final method in ['GET', 'POST', 'PATCH', 'PUT', 'DELETE']) {
      expect(output,
          contains('$method https://api.example/api/devices completed'));
    }
    expect(output, contains('status=200'));
    expect(output, contains('status=204'));
    expect(output, contains('elapsed_ms='));
    expect(output, isNot(contains('private-')));
  });

  test('HTTP status failures are logged and still reach the caller', () async {
    final api = ApiClient(
        client: MockClient((_) async =>
            http.Response('{"detail":"private-server-response"}', 503)));
    addTearDown(api.close);
    await expectLater(
        api.get('https://api.example/devices'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    final output = lines.join('\n');
    expect(output, contains('[ERROR][HTTP]'));
    expect(output, contains('status=503'));
    expect(output, isNot(contains('private-server-response')));
  });

  test('invalid JSON is distinguishable from a failed HTTP status', () async {
    final api = ApiClient(
        client: MockClient((_) async =>
            http.Response('{"password":"private-response" invalid}', 200)));
    addTearDown(api.close);
    await expectLater(
        api.get('https://api.example/devices'), throwsFormatException);
    final output = lines.join('\n');
    expect(output, contains('Invalid JSON/data format'));
    expect(output, contains('status=200'));
    expect(output, isNot(contains('private-response')));
  });

  test('timeouts and transport errors keep their original failure behavior',
      () async {
    final response = Completer<http.Response>();
    final api = ApiClient(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => response.future));
    addTearDown(api.close);
    await expectLater(api.get('https://api.example/devices'),
        throwsA(isA<TimeoutException>()));
    response.complete(http.Response('{}', 200));
    final failure = http.ClientException('private-transport-data');
    final offline = ApiClient(client: MockClient((_) async => throw failure));
    addTearDown(offline.close);
    await expectLater(
        offline.get('https://api.example/devices'), throwsA(same(failure)));
    final output = lines.join('\n');
    expect(output, contains('Request timed out'));
    expect(output, contains('status=none'));
    expect(output, isNot(contains('private-transport-data')));
  });

  test('caught command failures log their device context and still roll back',
      () async {
    final bloc = testDeviceBloc((request) async => request.method == 'GET'
        ? jsonResponse([deviceJson()])
        : http.Response('private-server-response', 503));
    await loadDevices(bloc);
    final failed =
        waitForDeviceState(bloc, (state) => state.updateError != null);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await failed;
    expect(bloc.state.devices.single.state['power'], isFalse);
    final output = lines.join('\n');
    expect(output, contains('[ERROR][DeviceBloc]'));
    expect(output, contains('device=device-001'));
    expect(output, isNot(contains('private-server-response')));
    expect(output, isNot(contains('{state:')));
  });

  test('socket diagnostics preserve delivery and retry without logging frames',
      () async {
    final channels = [FakeChannel(), FakeChannel()];
    var connections = 0;
    final realtime = HouseRealtimeRepository(
      socket: WebSocketService(
        endpoint: 'wss://api.example/ws?token=private-query',
        accessToken: () => 'private-access-token',
        connector: (_) => channels[connections++],
      ),
      retryDelays: const [Duration(milliseconds: 10)],
    );
    addTearDown(realtime.dispose);
    final errors = <Object>[];
    final delivered = Completer<void>();
    final messages = realtime.messages.listen((_) => delivered.complete(),
        onError: (Object error) => errors.add(error));
    addTearDown(messages.cancel);
    var connected = realtime.connectionStates
        .firstWhere((state) => state == SocketConnectionState.connected);
    realtime.start();
    await connected;
    channels[0].incoming.add('private-invalid-frame');
    channels[0].incoming.add('{"type":"device_state"}');
    channels[0].incoming.add(
        '{"type":"device_state","device_id":"d","state":{"secret":"private-value"}}');
    await delivered.future;
    expect(errors.length, 2);
    connected = realtime.connectionStates
        .firstWhere((state) => state == SocketConnectionState.connected);
    await channels[0].incoming.close();
    await connected.timeout(const Duration(seconds: 2));
    await channels[0].outgoing.close();
    expect(connections, 2);
    final output = lines.join('\n');
    expect(output, contains('Ignored malformed JSON frame'));
    expect(output, contains('Ignored invalid house message'));
    expect(output, contains('Connection closed by peer'));
    expect(output, contains('Reconnect scheduled'));
    expect(output, isNot(contains('private-')));
  });

  test('global hooks retain prior handlers and capture BLoC errors', () async {
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    final oldObserver = Bloc.observer;
    var frameworkCalls = 0;
    var platformCalls = 0;
    try {
      FlutterError.onError = (_) => frameworkCalls++;
      PlatformDispatcher.instance.onError = (_, __) {
        platformCalls++;
        return true;
      };
      installAppErrorLogging();
      final stack = StackTrace.current;
      FlutterError.onError!(FlutterErrorDetails(
          exception: StateError('private-framework-data'), stack: stack));
      expect(
          PlatformDispatcher.instance.onError!(
              StateError('private-platform-data'), stack),
          isTrue);
      final cubit = _TestCubit();
      cubit.reportFailure(StateError('private-cubit-data'), stack);
      await cubit.close();
      expect(frameworkCalls, 1);
      expect(platformCalls, 1);
      final output = lines.join('\n');
      expect(output, contains('[ERROR][Flutter]'));
      expect(output, contains('[ERROR][Platform]'));
      expect(output, contains('[ERROR][BLoC]'));
      expect(output, isNot(contains('private-')));
    } finally {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
      Bloc.observer = oldObserver;
    }
  });
}
