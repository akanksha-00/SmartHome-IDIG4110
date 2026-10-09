import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

import 'helpers/device_test_data.dart';
import 'helpers/fake_web_socket.dart';

DeviceMessage smoke(bool value, {bool? alert}) => DeviceMessage.fromJson({
      'type': 'device_event',
      'device_id': 'device-013',
      'event': 'smoke',
      'value': value,
      'alert': alert ?? value,
      'notification_message': value ? 'smoke detected in bedroom!' : null,
    })!;

void main() {
  test('decoder follows the backend envelopes and ignores unrelated types', () {
    expect(DeviceMessage.fromJson({'type': 'future_message'}), isNull);
    final message = smoke(true);
    expect(message.updates, {'smoke': true});
    expect(message.notificationMessage, 'smoke detected in bedroom!');
    expect(
        () => DeviceMessage.fromJson(
            {'type': 'device_state', 'device_id': 'x', 'state': []}),
        throwsFormatException);
    expect(
        () => DeviceMessage.fromJson({
              'type': 'device_event',
              'device_id': 'x',
              'event': 'smoke',
              'value': true,
              'alert': 'true'
            }),
        throwsFormatException);
  });

  test(
      'one socket consumes both message types, recovers after bad frames, and sends no subscriptions',
      () async {
    final channel = FakeChannel();
    var connections = 0;
    var sent = 0;
    channel.outgoing.stream.listen((_) => sent++);
    final repository = HouseRealtimeRepository(
        socket: WebSocketService(
      endpoint: 'ws://localhost:8001/api/v1/houses/house-001/ws',
      connector: (_) {
        connections++;
        return channel;
      },
    ));
    addTearDown(repository.dispose);
    final messages = <DeviceMessage>[];
    final errors = <Object>[];
    repository.messages.listen(messages.add, onError: errors.add);
    repository.start();
    repository.start();
    await Future<void>.delayed(Duration.zero);
    channel.incoming.add('not-json');
    channel.incoming.add(jsonEncode({
      'type': 'device_state',
      'device_id': 'device-014',
      'state': {'temperature': 35}
    }));
    channel.incoming.add(jsonEncode({
      'type': 'device_event',
      'device_id': 'device-013',
      'event': 'smoke',
      'value': true,
      'alert': true,
      'notification_message': 'Smoke!'
    }));
    await Future<void>.delayed(Duration.zero);
    expect(connections, 1);
    expect(sent, 0);
    expect(errors, hasLength(1));
    expect(messages, hasLength(2));
    expect(messages.first.updates, {'temperature': 35});
    expect(messages.last.alert, true);
  });

  test('remote close reconnects once; disposal stops subsequent retries',
      () async {
    final channels = <FakeChannel>[];
    final repository = HouseRealtimeRepository(
      retryDelays: const [Duration(milliseconds: 5)],
      socket: WebSocketService(
          endpoint: 'ws://localhost/ws',
          connector: (_) {
            final channel = FakeChannel();
            channels.add(channel);
            return channel;
          }),
    );
    repository.messages.listen((_) {}, onError: (Object _) {});
    repository.start();
    await Future<void>.delayed(Duration.zero);
    await channels.first.incoming.close();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(channels, hasLength(2));
    expect(repository.connectionState, SocketConnectionState.connected);
    await repository.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(channels, hasLength(2));
  });

  test('failed handshake retries and does not create an unhandled error',
      () async {
    var calls = 0;
    final repository = HouseRealtimeRepository(
        retryDelays: const [Duration(milliseconds: 5)],
        socket: WebSocketService(
            endpoint: 'ws://localhost/ws',
            connector: (_) {
              calls++;
              if (calls == 1) throw StateError('Network unavailable');
              return FakeChannel();
            }));
    addTearDown(repository.dispose);
    final errors = <Object>[];
    repository.messages.listen((_) {}, onError: errors.add);
    repository.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 2);
    expect(errors, hasLength(1));
    expect(repository.connectionState, SocketConnectionState.connected);
  });

  test('alerts and cached readings remain immediate during a slow refresh',
      () async {
    final response = Completer<http.Response>();
    var gets = 0;
    final bloc = testDeviceBloc((_) async {
      gets++;
      return gets == 1
          ? jsonResponse(
              [sensorJson('device-013', 'smoke_detector', 'smoke', false)])
          : response.future;
    });
    await loadDevices(bloc);
    final loading =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested(force: true));
    await loading;
    final alerted = waitForDeviceState(bloc, (s) => s.alertRevision == 1);
    bloc.add(DeviceRealtimeReceived(smoke(true)));
    await alerted;
    expect(bloc.state.devices.single.state['smoke'], true);
    final loaded =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loaded);
    response.complete(jsonResponse(
        [sensorJson('device-013', 'smoke_detector', 'smoke', false)]));
    await loaded;
    expect(bloc.state.devices.single.state['smoke'], true);
    expect(bloc.state.alerts, hasLength(1));
  });

  test('live reports do not finish PATCH before its HTTP response', () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((r) async =>
        r.method == 'GET' ? jsonResponse([deviceJson()]) : response.future);
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'brightness': 40}));
    await pending;
    final unrelated = waitForDeviceState(
        bloc, (s) => s.devices.single.state['power'] == true);
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-001', updates: {'power': true})));
    await unrelated;
    expect(bloc.state.pendingDeviceIds, contains('device-001'));
    final confirmed =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    response.complete(jsonResponse(deviceJson()));
    await confirmed;
    expect(bloc.state.devices.single.state['power'], true);
  });

  test('a saved PATCH response survives a concurrent older GET snapshot',
      () async {
    var gets = 0;
    final patchResponse = Completer<http.Response>();
    final refreshResponse = Completer<http.Response>();
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        gets++;
        return gets == 1
            ? jsonResponse([deviceJson()])
            : refreshResponse.future;
      }
      return patchResponse.future;
    });
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    final refreshing =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested(force: true));
    await refreshing;
    final saved = waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    patchResponse.complete(jsonResponse(deviceJson(power: true)));
    await saved;
    final loaded =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loaded);
    refreshResponse.complete(jsonResponse([deviceJson()]));
    await loaded;
    expect(bloc.state.devices.single.state['power'], true);
    expect(bloc.state.updateError, isNull);
  });

  test('refresh keeps optimistic values while PATCH is still in flight',
      () async {
    final patchResponse = Completer<http.Response>();
    final refreshResponse = Completer<http.Response>();
    var gets = 0;
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        return ++gets == 1
            ? jsonResponse([deviceJson()])
            : refreshResponse.future;
      }
      return patchResponse.future;
    });
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await pending;
    final refreshing =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested(force: true));
    await refreshing;
    final loaded =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loaded);
    refreshResponse.complete(jsonResponse([deviceJson()]));
    await loaded;
    expect(bloc.state.devices.single.state['power'], true);
    expect(bloc.state.pendingDeviceIds, {'device-001'});
    final saved = waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isEmpty);
    patchResponse.complete(jsonResponse(deviceJson(power: true)));
    await saved;
    expect(bloc.state.devices.single.state['power'], true);
  });

  test('a rollback survives a concurrent stale refresh', () async {
    final patchResponse = Completer<http.Response>();
    final refreshResponse = Completer<http.Response>();
    var gets = 0;
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') {
        return ++gets == 1
            ? jsonResponse([deviceJson()])
            : refreshResponse.future;
      }
      return patchResponse.future;
    });
    await loadDevices(bloc);
    final pending =
        waitForDeviceState(bloc, (s) => s.pendingDeviceIds.isNotEmpty);
    bloc.add(DeviceStateUpdateRequested(
        id: 'device-001', updates: {'brightness': 80}));
    await pending;
    final refreshing =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested(force: true));
    await refreshing;
    final failed = waitForDeviceState(bloc, (s) => s.updateError != null);
    patchResponse.complete(http.Response('Unavailable', 503));
    await failed;
    expect(bloc.state.devices.single.state['brightness'], 40);
    final loaded =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loaded);
    refreshResponse.complete(jsonResponse([deviceJson(brightness: 25)]));
    await loaded;
    expect(bloc.state.devices.single.state['brightness'], 40);
    expect(bloc.state.pendingDeviceIds, isEmpty);
  });

  test('reports during initial GET win over the older HTTP snapshot', () async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((_) => response.future);
    final loading =
        waitForDeviceState(bloc, (s) => s.status == DeviceLoadStatus.loading);
    bloc.add(const DevicesRequested());
    await loading;
    bloc.add(DeviceRealtimeReceived(DeviceMessage(
        deviceId: 'device-001', updates: {'power': true, 'brightness': 80})));
    await Future<void>.delayed(Duration.zero);
    final loaded = waitForDeviceState(bloc, (s) => s.hasLoaded);
    response.complete(jsonResponse([deviceJson()]));
    await loaded;
    expect(bloc.state.devices.single.state, {'power': true, 'brightness': 80});
  });

  test(
      'partial reports merge and only backend alert:true creates a notification',
      () async {
    final bloc = testDeviceBloc((_) async => jsonResponse([
          sensorJson('device-013', 'smoke_detector', 'smoke', false),
          sensorJson('device-014', 'temperature_sensor', 'temperature', 35),
        ]));
    await loadDevices(bloc);
    final reading = waitForDeviceState(
        bloc, (s) => s.devices.last.state['temperature'] == 36);
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-014', updates: {'temperature': 36})));
    await reading;
    expect(bloc.state.alerts, isEmpty); // No frontend threshold inference.
    final alarm = waitForDeviceState(bloc, (s) => s.unreadAlertCount == 1);
    bloc.add(DeviceRealtimeReceived(smoke(true)));
    await alarm;
    expect(bloc.state.devices.first.state['smoke'], true);
    expect(bloc.state.alerts.single.message, 'smoke detected in bedroom!');
    bloc.add(DeviceRealtimeReceived(smoke(true))); // Duplicate active alert.
    final read = waitForDeviceState(bloc, (s) => s.unreadAlertCount == 0);
    bloc.add(const DeviceAlertsRead());
    await read;
    expect(bloc.state.alerts, hasLength(1));
    final cleared = waitForDeviceState(bloc, (s) => !s.alerts.single.isActive);
    bloc.add(DeviceRealtimeReceived(smoke(false)));
    await cleared;
    expect(bloc.state.devices.first.state['smoke'], false);
    final second = waitForDeviceState(bloc, (s) => s.alertRevision == 2);
    bloc.add(DeviceRealtimeReceived(smoke(true)));
    await second;
    expect(bloc.state.alerts, hasLength(2));
    expect(bloc.state.unreadAlertCount, 1);
  });

  test('unknown devices use one GET while known reports continue immediately',
      () async {
    var individualGets = 0;
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((r) async {
      if (r.url.path.endsWith('/devices')) return jsonResponse([deviceJson()]);
      individualGets++;
      return response.future;
    });
    await loadDevices(bloc);
    bloc.add(DeviceRealtimeReceived(smoke(true)));
    bloc.add(DeviceRealtimeReceived(smoke(false)));
    final changed = waitForDeviceState(
        bloc, (s) => s.devices.first.state['brightness'] == 90);
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-001', updates: {'brightness': 90})));
    await changed;
    expect(individualGets, 1);
    expect(bloc.state.alerts, hasLength(1));
    final discovered = waitForDeviceState(bloc,
        (s) => s.devices.length == 2 && s.devices.last.state['smoke'] == false);
    response.complete(jsonResponse(
        sensorJson('device-013', 'smoke_detector', 'smoke', false)));
    await discovered;
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.alertRevision, 1);
    expect(bloc.state.alerts.single.isActive, false);
  });

  test(
      'connecting and reconnecting resync state but retain notification history',
      () async {
    final channels = <FakeChannel>[];
    var gets = 0;
    final realtime = HouseRealtimeRepository(
        retryDelays: const [Duration(milliseconds: 5)],
        socket: WebSocketService(
            endpoint: 'ws://localhost/ws',
            connector: (_) {
              final c = FakeChannel(readyNow: false);
              channels.add(c);
              return c;
            }));
    final bloc = testDeviceBloc((_) async {
      gets++;
      return jsonResponse(
          [sensorJson('device-013', 'smoke_detector', 'smoke', gets >= 3)]);
    }, realtime: realtime);
    await loadDevices(bloc);
    final firstConnected = waitForDeviceState(
        bloc, (s) => s.connection == SocketConnectionState.connected);
    channels.first.handshake.complete();
    await firstConnected;
    await Future<void>.delayed(Duration.zero);
    final alert = waitForDeviceState(bloc, (s) => s.alerts.isNotEmpty);
    channels.first.incoming.add(jsonEncode({
      'type': 'device_event',
      'device_id': 'device-013',
      'event': 'smoke',
      'value': true,
      'alert': true,
      'notification_message': 'Smoke!'
    }));
    await alert;
    final disconnected = waitForDeviceState(
        bloc, (s) => s.connection == SocketConnectionState.disconnected);
    await channels.first.incoming.close();
    await disconnected;
    expect(bloc.state.hasLoaded, true);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final resynced = waitForDeviceState(
        bloc,
        (s) =>
            s.status == DeviceLoadStatus.loaded &&
            s.connection == SocketConnectionState.connected &&
            gets == 3);
    channels.last.handshake.complete();
    await resynced;
    expect(gets, 3);
    expect(bloc.state.devices.single.state['smoke'], true);
    expect(bloc.state.alerts.single.message, 'Smoke!');
  });

  test('PATCH controls work while WebSocket is disconnected', () async {
    final channel = FakeChannel(readyNow: false);
    final realtime = HouseRealtimeRepository(
        socket: WebSocketService(
            endpoint: 'ws://localhost/ws', connector: (_) => channel));
    var patches = 0;
    final bloc = testDeviceBloc((r) async {
      if (r.method == 'GET') return jsonResponse([deviceJson()]);
      expect(r.method, 'PATCH');
      patches++;
      return jsonResponse(deviceJson(power: true));
    }, realtime: realtime);
    await loadDevices(bloc);
    expect(bloc.state.connection, isNot(SocketConnectionState.connected));
    final saved = waitForDeviceState(
        bloc,
        (s) =>
            s.devices.single.state['power'] == true &&
            s.pendingDeviceIds.isEmpty);
    bloc.add(
        DeviceStateUpdateRequested(id: 'device-001', updates: {'power': true}));
    await saved;
    expect(patches, 1);
    expect(bloc.state.pendingDeviceIds, isEmpty);
    expect(bloc.state.updateError, isNull);
    channel.handshake.complete();
  });
}
