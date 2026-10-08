import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/models/devices/device_create_request.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/models/devices/device_message.dart';

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

  test('PATCH saves the returned state without waiting for a live report',
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
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    expect(bloc.state.devices.single.state['power'], false);
    final confirmed =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    response.complete(jsonResponse(deviceJson(power: true)));
    await confirmed;
    expect(bloc.state.devices.single.state['power'], true);
    expect(bloc.state.devices.single.state['brightness'], 40);
    expect(bloc.state.devices.single.name, 'Ceiling Light');
  });

  test(
      'live sensor/state reports are processed during PATCH; failure never rolls them back',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async => request.method == 'GET'
        ? jsonResponse(
            [deviceJson(), deviceJson(id: 'device-002', type: 'fan')])
        : response.future);
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    final received = waitForDeviceState(
        bloc, (s) => s.devices.first.state['brightness'] == 90);
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-001', updates: {'brightness': 90})));
    await received;
    final failed = waitForDeviceState(bloc, (s) => s.updateError != null);
    response.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.first.state['power'], false);
    expect(bloc.state.devices.first.state['brightness'], 90);
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.devices, hasLength(2));
  });

  test('newer live reports take precedence over the PATCH response', () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((r) async =>
        r.method == 'GET' ? jsonResponse([deviceJson()]) : response.future);
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    final received = waitForDeviceState(
        bloc, (s) => s.devices.single.state['brightness'] == 80);
    bloc.add(DeviceRealtimeReceived(DeviceMessage(
        deviceId: 'device-001', updates: {'power': false, 'brightness': 80})));
    await received;
    expect(bloc.state.pendingDeviceIds, contains('device-001'));
    final saved = waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    response.complete(jsonResponse(deviceJson(power: true, brightness: 40)));
    await saved;
    expect(bloc.state.devices.single.state['power'], false);
    expect(bloc.state.devices.single.state['brightness'], 80);
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.updateError, isNull);
  });

  test('an HTTP timeout clears the pending update without resending', () async {
    var patches = 0;
    var gets = 0;
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        gets++;
        return jsonResponse([deviceJson()]);
      }
      expect(r.method, 'PATCH');
      patches++;
      throw TimeoutException('HTTP request timed out');
    });
    await loadDevices(bloc);
    final failed =
        waitForDeviceState(bloc, (s) => s.updateError is TimeoutException);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await failed;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.devices.single.state['power'], false);
    expect(patches, 1);
    expect(gets, 1);
  });

  test('a PATCH response for another device cannot replace the loaded state',
      () async {
    final bloc = testDeviceBloc((r) async => r.method == 'GET'
        ? jsonResponse([deviceJson()])
        : jsonResponse(deviceJson(id: 'device-other', power: true)));
    await loadDevices(bloc);
    final failed =
        waitForDeviceState(bloc, (s) => s.updateError is FormatException);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await failed;
    expect(bloc.state.devices.single.id, 'device-001');
    expect(bloc.state.devices.single.state['power'], false);
    expect(bloc.state.pendingDeviceIds, isEmpty);
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
