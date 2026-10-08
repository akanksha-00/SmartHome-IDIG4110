import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/main.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/widgets/device_repository_scope.dart';
import 'package:smart_home/src/widgets/device_startup_gate.dart';

Map<String, Object?> deviceJson() => {
      'id': 'device-001',
      'name': 'Ceiling Light',
      'type': 'light',
      'house_id': 'house-001',
      'room_id': 'living-room',
      'capabilities': {
        'power': {'type': 'boolean'}
      },
      'state': {'power': false},
      'status': {'operational': true},
    };

http.Response devicesResponse([List<Object?>? devices]) =>
    http.Response(jsonEncode(devices ?? [deviceJson()]), 200);

DeviceRepository repositoryWith(
    Future<http.Response> Function(http.Request) handler) {
  final client = ApiClient(client: MockClient(handler));
  final repository =
      DeviceRepository(apiClient: client, houseId: AppConfig.houseId);
  addTearDown(() {
    repository.dispose();
    client.close();
  });
  return repository;
}

Widget startupHarness(DeviceRepository repository) => DeviceRepositoryScope(
      repository: repository,
      child: MaterialApp(
        home: DeviceStartupGate(
          repository: repository,
          child: Builder(builder: (context) {
            final cached = DeviceRepositoryScope.of(context).devices;
            return Scaffold(body: Text('Loaded ${cached.length} devices'));
          }),
        ),
      ),
    );

void main() {
  test(
      'load caches house devices, publishes states, and shares concurrent requests',
      () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final repo = repositoryWith((request) {
      calls++;
      expect(request.url.path, '/api/v1/houses/house-001/devices');
      return response.future;
    });
    final states = <DeviceLoadState>[];
    repo.addListener(() => states.add(repo.loadState));
    final first = repo.loadDevices();
    final second = repo.loadDevices();
    expect(repo.loadState, DeviceLoadState.loading);
    expect(identical(first, second), isTrue);
    response.complete(devicesResponse());
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(repo.devices.single.id, 'device-001');
    expect(repo.loadState, DeviceLoadState.loaded);
    expect(states, [DeviceLoadState.loading, DeviceLoadState.loaded]);
    expect(() => repo.devices.clear(), throwsUnsupportedError);
  });

  test('a load requested by a loading listener shares the same fetch',
      () async {
    var calls = 0;
    final repo = repositoryWith((request) async {
      calls++;
      return devicesResponse();
    });
    Future<void>? listenerLoad;
    repo.addListener(() {
      if (repo.loadState == DeviceLoadState.loading) {
        listenerLoad = repo.loadDevices();
      }
    });
    final first = repo.loadDevices();
    expect(identical(first, listenerLoad), isTrue);
    await first;
    expect(calls, 1);
    expect(repo.devices, hasLength(1));
  });

  test('room fetches cannot replace the full house cache', () async {
    final repo = repositoryWith((request) async {
      return request.url.path.contains('/rooms/')
          ? devicesResponse([])
          : devicesResponse();
    });
    await repo.loadDevices();
    expect(await repo.fetchDevices(roomId: 'kitchen'), isEmpty);
    expect(repo.devices.single.name, 'Ceiling Light');
  });

  test(
      'failed refresh keeps cached devices and a subsequent retry clears the error',
      () async {
    var calls = 0;
    final repo = repositoryWith((request) async {
      calls++;
      return calls == 2 ? http.Response('Unavailable', 503) : devicesResponse();
    });
    await repo.loadDevices();
    await expectLater(repo.loadDevices(), throwsA(isA<ApiException>()));
    expect(repo.loadState, DeviceLoadState.failed);
    expect(repo.loadError, isA<ApiException>());
    expect(repo.devices.single.id, 'device-001');
    await repo.loadDevices();
    expect(repo.loadState, DeviceLoadState.loaded);
    expect(repo.loadError, isNull);
  });

  test('disposal prevents late notifications from an in-flight load', () async {
    final response = Completer<http.Response>();
    final client = ApiClient(client: MockClient((request) => response.future));
    final repo =
        DeviceRepository(apiClient: client, houseId: AppConfig.houseId);
    addTearDown(client.close);
    var notifications = 0;
    repo.addListener(() => notifications++);
    final loading = repo.loadDevices();
    repo.dispose();
    response.complete(devicesResponse());
    await loading;
    expect(notifications, 1);
  });

  testWidgets(
      'startup changes from loading to loaded and supplies the cached repository',
      (tester) async {
    final response = Completer<http.Response>();
    final repo = repositoryWith((request) => response.future);
    await tester.pumpWidget(startupHarness(repo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loaded 1 devices'), findsNothing);
    response.complete(devicesResponse());
    await tester.pumpAndSettle();
    expect(find.text('Loaded 1 devices'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an empty house is loaded successfully', (tester) async {
    final repo = repositoryWith((request) async => devicesResponse([]));
    await tester.pumpWidget(startupHarness(repo));
    await tester.pumpAndSettle();
    expect(find.text('Loaded 0 devices'), findsOneWidget);
    expect(repo.loadState, DeviceLoadState.loaded);
  });

  testWidgets('failed startup offers retry and recovers into loaded state',
      (tester) async {
    var calls = 0;
    final repo = repositoryWith((request) async {
      calls++;
      return calls == 1 ? http.Response('Unavailable', 503) : devicesResponse();
    });
    await tester.pumpWidget(startupHarness(repo));
    await tester.pumpAndSettle();
    expect(find.text('Could not load devices'), findsOneWidget);
    expect(find.text('Loaded 1 devices'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Loaded 1 devices'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('ordinary rebuilds do not fetch the house again', (tester) async {
    var calls = 0;
    final repo = repositoryWith((request) async {
      calls++;
      return devicesResponse();
    });
    await tester.pumpWidget(startupHarness(repo));
    await tester.pumpAndSettle();
    await tester.pumpWidget(startupHarness(repo));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
      'the actual app initially gates the dashboard behind device loading',
      (tester) async {
    final response = Completer<http.Response>();
    final repo = repositoryWith((request) => response.future);
    await tester.pumpWidget(MyApp(deviceRepository: repo));
    expect(find.text('Loading devices…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(devicesResponse([]));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
