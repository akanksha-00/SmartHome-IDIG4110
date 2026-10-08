import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/models/devices/device_create_request.dart';
import 'package:smart_home/src/repositories/api_client.dart';

import 'helpers/device_test_data.dart';

void main() {
  test('startup hydrates an immutable list owned by DeviceBloc', () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/houses/house-001/devices');
      return response.future;
    });
    final loading = waitForDeviceState(
        bloc, (state) => state.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested());
    await loading;
    expect(bloc.state.devices, isEmpty);
    final loaded = waitForDeviceState(bloc, (state) => state.hasLoaded);
    response.complete(jsonResponse([deviceJson()]));
    await loaded;
    expect(bloc.state.status, DeviceLoadStatus.loaded);
    expect(bloc.state.devices.single.id, 'device-001');
    expect(() => bloc.state.devices.clear(), throwsUnsupportedError);
    expect(() => bloc.state.devices.single.state['power'] = true,
        throwsUnsupportedError);
  });

  test('an empty response counts as successfully loaded', () async {
    final bloc = testDeviceBloc((_) async => jsonResponse([]));
    await loadDevices(bloc);
    expect(bloc.state.devices, isEmpty);
    expect(bloc.state.hasLoaded, isTrue);
  });

  test('startup failure supports retry and clears its error', () async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return calls == 1
          ? http.Response('Unavailable', 503)
          : jsonResponse([deviceJson()]);
    });
    final failed = waitForDeviceState(
        bloc, (state) => state.status == DeviceLoadStatus.failed);
    bloc.add(const DevicesRequested());
    await failed;
    expect(bloc.state.hasLoaded, isFalse);
    expect(bloc.state.loadError, isA<ApiException>());
    await loadDevices(bloc);
    expect(bloc.state.loadError, isNull);
    expect(calls, 2);
  });

  test('duplicate startup requests do not fetch an already loaded house again',
      () async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return jsonResponse([deviceJson()]);
    });
    bloc.add(const DevicesRequested());
    await loadDevices(bloc);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('a failed refresh retains the loaded list and can be retried explicitly',
      () async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return calls == 2
          ? http.Response('Unavailable', 503)
          : jsonResponse([deviceJson()]);
    });
    await loadDevices(bloc);
    final failed = waitForDeviceState(
        bloc, (state) => state.status == DeviceLoadStatus.failed);
    bloc.add(const DevicesRequested(force: true));
    await failed;
    expect(bloc.state.hasLoaded, isTrue);
    expect(bloc.state.devices.single.id, 'device-001');
    final refreshed = waitForDeviceState(
        bloc, (state) => state.status == DeviceLoadStatus.loaded);
    bloc.add(const DevicesRequested(force: true));
    await refreshed;
    expect(bloc.state.loadError, isNull);
  });

  test(
      'PATCH is optimistic, uses capability updates, then trusts the full response',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([deviceJson()]);
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/houses/house-001/devices/device-001');
      expect(jsonDecode(request.body), [
        {'name': 'power', 'value': true}
      ]);
      return response.future;
    });
    await loadDevices(bloc);
    final original = bloc.state.devices.single;
    final pending =
        waitForDeviceState(bloc, (state) => state.updatingDeviceId != null);
    bloc.add(
        DeviceStateUpdateRequested(id: original.id, updates: {'power': true}));
    await pending;
    expect(bloc.state.devices.single.state['power'], isTrue);
    expect(original.state['power'], isFalse);
    final saved =
        waitForDeviceState(bloc, (state) => state.updatingDeviceId == null);
    response.complete(jsonResponse(
        deviceJson(name: 'Server light', power: true, brightness: 66)));
    await saved;
    expect(bloc.state.devices.single.name, 'Server light');
    expect(bloc.state.devices.single.state['brightness'], 66);
  });

  test('failed PATCH rolls back the original record and keeps other devices',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async => request.method == 'GET'
        ? jsonResponse(
            [deviceJson(), deviceJson(id: 'device-002', type: 'fan')])
        : response.future);
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (state) => state.updatingDeviceId != null);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    final failed =
        waitForDeviceState(bloc, (state) => state.updateError != null);
    response.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.first.state['power'], isFalse);
    expect(bloc.state.devices, hasLength(2));
    expect(bloc.state.updatingDeviceId, isNull);
    expect(bloc.state.updateErrorRevision, 1);
  });

  test('queued PATCHes preserve ordering and changes to other capabilities',
      () async {
    final firstResponse = Completer<http.Response>();
    var writes = 0;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([deviceJson()]);
      writes++;
      if (writes == 1) return firstResponse.future;
      expect(jsonDecode(request.body), [
        {'name': 'brightness', 'value': 75}
      ]);
      return jsonResponse(deviceJson(power: true, brightness: 75));
    });
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (state) => state.updatingDeviceId != null);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'brightness': 75}));
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(writes, 1);
    final finished = waitForDeviceState(
        bloc,
        (state) =>
            state.updatingDeviceId == null &&
            state.devices.first.state['brightness'] == 75);
    firstResponse.complete(jsonResponse(deviceJson(power: true)));
    await finished;
    expect(writes, 2);
    expect(bloc.state.devices.single.state['power'], isTrue);
  });

  test('creating a device appends the server response after POST succeeds',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([deviceJson()]);
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['id'], 'device-new');
      expect(body['room_id'], 'bedroom');
      expect(body.containsKey('subtitle'), isFalse);
      return response.future;
    });
    await loadDevices(bloc);
    final adding = waitForDeviceState(bloc, (state) => state.isAdding);
    bloc.add(DeviceAddRequested(DeviceCreateRequest(
        id: 'device-new',
        name: 'New light',
        type: 'light',
        roomId: 'bedroom')));
    await adding;
    expect(bloc.state.devices, hasLength(1));
    final added = waitForDeviceState(
        bloc, (state) => state.lastAddedDeviceId == 'device-new');
    response.complete(jsonResponse(
        deviceJson(id: 'device-new', name: 'New light', roomId: 'bedroom')));
    await added;
    expect(bloc.state.devices, hasLength(2));
    expect(bloc.state.devices.last.roomId, 'bedroom');
    expect(bloc.state.isAdding, isFalse);
  });

  test('failed creation preserves the list and a retry clears the add error',
      () async {
    var writes = 0;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([deviceJson()]);
      writes++;
      return writes == 1
          ? http.Response('Unavailable', 503)
          : jsonResponse(deviceJson(id: 'device-new'));
    });
    await loadDevices(bloc);
    final event = DeviceAddRequested(DeviceCreateRequest(
        id: 'device-new',
        name: 'New light',
        type: 'light',
        roomId: 'living-room'));
    final failed = waitForDeviceState(bloc, (state) => state.addError != null);
    bloc.add(event);
    await failed;
    expect(bloc.state.devices, hasLength(1));
    final added = waitForDeviceState(
        bloc, (state) => state.lastAddedDeviceId == 'device-new');
    bloc.add(event);
    await added;
    expect(bloc.state.addError, isNull);
    expect(bloc.state.devices, hasLength(2));
  });

  test('duplicate IDs and unloaded device updates cannot send requests',
      () async {
    var calls = 0;
    final bloc = testDeviceBloc((_) async {
      calls++;
      return jsonResponse([deviceJson()]);
    });
    await loadDevices(bloc);
    final failedAdd =
        waitForDeviceState(bloc, (state) => state.addError != null);
    bloc.add(DeviceAddRequested(DeviceCreateRequest(
        id: 'device-001',
        name: 'Duplicate',
        type: 'light',
        roomId: 'living-room')));
    await failedAdd;
    final failedUpdate =
        waitForDeviceState(bloc, (state) => state.updateError != null);
    bloc.add(
        DeviceStateUpdateRequested(id: 'missing', updates: {'power': true}));
    await failedUpdate;
    expect(calls, 1);
  });

  test('closing a BLoC during startup prevents a late state emission',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((_) => response.future);
    final loading = waitForDeviceState(
        bloc, (state) => state.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested());
    await loading;
    await bloc.close().timeout(const Duration(seconds: 3));
    response.complete(jsonResponse([deviceJson()]));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.isClosed, isTrue);
    expect(bloc.state.devices, isEmpty);
  });
}
