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

  test('a control updates immediately before the command is acknowledged',
      () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([deviceJson()]);
      expect(request.method, 'POST');
      expect(request.url.path,
          '/api/v1/houses/house-001/devices/device-001/command');
      expect(jsonDecode(request.body), {
        'state': {'power': true, 'brightness': 40}
      });
      return response.future;
    });
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    expect(bloc.state.devices.single.state['power'], true);
    final confirmed =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    response.complete(jsonResponse(commandAck(state: {'power': true})));
    await confirmed;
    expect(bloc.state.devices.single.state['power'], true);
    expect(bloc.state.devices.single.state['brightness'], 40);
    expect(bloc.state.devices.single.name, 'Ceiling Light');
  });

  test(
      'live reports are processed during commands; failure never rolls them back',
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

  test('fan commands retain all state values across successive edits',
      () async {
    final fan = deviceJson(type: 'fan', power: true, speed: 3);
    (fan['capabilities'] as Map)['oscillation'] = {'type': 'boolean'};
    (fan['state'] as Map)['oscillation'] = false;
    final commands = <Map<String, dynamic>>[];
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([fan]);
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      commands.add(body);
      return jsonResponse(commandAck(state: body['state']));
    });
    await loadDevices(bloc);
    final speedSaved = waitForDeviceState(
        bloc,
        (s) =>
            s.devices.single.state['speed'] == 5 && s.pendingDeviceIds.isEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'speed': 5}));
    await speedSaved;
    final powerSaved = waitForDeviceState(
        bloc,
        (s) =>
            s.devices.single.state['power'] == false &&
            s.pendingDeviceIds.isEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'power': false}));
    await powerSaved;
    expect(commands, [
      {
        'state': {'power': true, 'speed': 5, 'oscillation': false}
      },
      {
        'state': {'power': false, 'speed': 5, 'oscillation': false}
      },
    ]);
    expect(bloc.state.devices.single.state,
        {'power': false, 'speed': 5, 'oscillation': false});
  });

  test('a full command includes the latest values received over WebSocket',
      () async {
    final fan = deviceJson(type: 'fan', power: true, speed: 3);
    (fan['capabilities'] as Map)['oscillation'] = {'type': 'boolean'};
    (fan['state'] as Map)['oscillation'] = false;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse([fan]);
      expect(jsonDecode(request.body), {
        'state': {'power': false, 'speed': 4, 'oscillation': true}
      });
      return jsonResponse(commandAck());
    });
    await loadDevices(bloc);
    final received = waitForDeviceState(
        bloc, (s) => s.devices.single.state['oscillation'] == true);
    bloc.add(DeviceRealtimeReceived(DeviceMessage(
        deviceId: 'device-001', updates: {'speed': 4, 'oscillation': true})));
    await received;
    final saved = waitForDeviceState(
        bloc,
        (s) =>
            s.devices.single.state['power'] == false &&
            s.pendingDeviceIds.isEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'power': false}));
    await saved;
    expect(bloc.state.updateError, isNull);
  });

  test('failure keeps a newer live value for the same capability', () async {
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
        bloc, (s) => s.devices.single.state['brightness'] == 88);
    bloc.add(DeviceRealtimeReceived(DeviceMessage(
        deviceId: 'device-001', updates: {'power': true, 'brightness': 88})));
    await received;
    final failed = waitForDeviceState(bloc, (s) => s.updateError != null);
    response.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.single.state, {'power': true, 'brightness': 88});
    expect(bloc.state.pendingDeviceIds, isEmpty);
  });

  test(
      'failure removes an optimistic capability that originally had no reading',
      () async {
    final response = Completer<http.Response>();
    final json = deviceJson();
    (json['state'] as Map<String, Object?>).remove('brightness');
    final bloc = testDeviceBloc((r) async =>
        r.method == 'GET' ? jsonResponse([json]) : response.future);
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'brightness': 70}));
    await pending;
    expect(bloc.state.devices.single.state['brightness'], 70);
    final failed = waitForDeviceState(bloc, (s) => s.updateError != null);
    response.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.single.state.containsKey('brightness'), false);
    expect(bloc.state.devices.single.state['power'], false);
  });

  test(
      'different devices update immediately and failures roll back only their own device',
      () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final writes = <String>[];
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        return jsonResponse(
            [deviceJson(), deviceJson(id: 'device-002', type: 'fan')]);
      }
      final id = r.url.pathSegments[r.url.pathSegments.length - 2];
      writes.add(id);
      return id == 'device-001' ? first.future : second.future;
    });
    await loadDevices(bloc);
    final both =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.length == 2);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-002', updates: {'power': true}));
    await both;
    expect(bloc.state.devices.every((d) => d.state['power'] == true), true);
    // A second save for an already pending device is discarded, not queued.
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'power': false}));
    await Future<void>.delayed(Duration.zero);
    expect(writes, ['device-001', 'device-002']);
    final failed = waitForDeviceState(bloc, (s) => s.updateError != null);
    first.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.first.state['power'], false);
    expect(bloc.state.devices.last.state['power'], true);
    expect(bloc.state.pendingDeviceIds, {'device-002'});
    final saved = waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    second.complete(
        jsonResponse(commandAck(id: 'device-002', state: {'power': true})));
    await saved;
    expect(bloc.state.devices.last.state['power'], true);
    expect(writes, hasLength(2));
  });

  test('an acknowledgement cannot overwrite newer live reports', () async {
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
    response.complete(
        jsonResponse(commandAck(state: {'power': true, 'brightness': 40})));
    await saved;
    expect(bloc.state.devices.single.state['power'], false);
    expect(bloc.state.devices.single.state['brightness'], 80);
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.updateError, isNull);
  });

  test('a later device report replaces optimistic state after acknowledgement',
      () async {
    final bloc = testDeviceBloc((request) async => request.method == 'GET'
        ? jsonResponse([deviceJson()])
        : jsonResponse(commandAck(state: {'power': true, 'brightness': 70})));
    await loadDevices(bloc);
    final acknowledged = waitForDeviceState(
        bloc,
        (s) =>
            s.devices.single.state['power'] == true &&
            s.pendingDeviceIds.isEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'power': true, 'brightness': 70}));
    await acknowledged;
    expect(bloc.state.devices.single.state['brightness'], 70);
    final reported = waitForDeviceState(
        bloc, (s) => s.devices.single.state['brightness'] == 65);
    bloc.add(DeviceRealtimeReceived(DeviceMessage(
        deviceId: 'device-001', updates: {'power': false, 'brightness': 65})));
    await reported;
    expect(bloc.state.devices.single.state['power'], false);
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.updateError, isNull);
  });

  test('an HTTP timeout clears the pending update without resending', () async {
    var commands = 0;
    var gets = 0;
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        gets++;
        return jsonResponse([deviceJson()]);
      }
      expect(r.method, 'POST');
      commands++;
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
    expect(commands, 1);
    expect(gets, 1);
  });

  test('an acknowledgement for another device rolls back the local update',
      () async {
    final bloc = testDeviceBloc((r) async => r.method == 'GET'
        ? jsonResponse([deviceJson()])
        : jsonResponse(commandAck(id: 'device-other')));
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
