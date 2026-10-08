import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/models/sensors/sensor_reading.dart';
import 'package:smart_home/src/repositories/sensor_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';
import 'helpers/fake_web_socket.dart';

WebSocketService createSocket(FakeChannel channel) {
  final socket = WebSocketService(
    endpoint: 'wss://example.com/test-stream',
    connector: (uri) => channel,
  );
  addTearDown(socket.dispose);
  return socket;
}

// A test protocol only; this is not a claim about the backend's wire format.
Iterable<SensorReading> decodeTestMessage(Map<String, dynamic> json) {
  if (json['event'] != 'test-readings') return const [];
  return (json['readings'] as List).map((reading) => SensorReading(
        id: reading['deviceId'] as String,
        deviceId: reading['deviceId'] as String,
        roomId: reading['roomId'] as String,
        type: 'temperature',
        value: reading['value'],
        isOnline: reading['isOnline'] as bool,
      ));
}

void main() {
  test('missing and invalid URLs do not open connections', () async {
    var calls = 0;
    for (final url in [null, '', 'https://example.com', 'wss:/missing-host']) {
      final socket = WebSocketService(
          endpoint: url,
          connector: (uri) {
            calls++;
            return FakeChannel();
          });
      addTearDown(socket.dispose);
      await expectLater(
          socket.connect(),
          url == null || url.isEmpty
              ? throwsUnsupportedError
              : throwsArgumentError);
    }
    expect(calls, 0);
  });

  test('concurrent listeners and connect calls share one handshake', () async {
    final channel = FakeChannel(readyNow: false);
    var calls = 0;
    final socket = WebSocketService(
        endpoint: 'wss://example.com/test',
        connector: (uri) {
          calls++;
          return channel;
        });
    addTearDown(socket.dispose);
    final firstMessage = socket.messages.first;
    final secondMessage = socket.messages.first;
    final firstConnect = socket.connect();
    final secondConnect = socket.connect();
    expect(socket.state, SocketConnectionState.connecting);
    expect(calls, 1);
    channel.handshake.complete();
    await Future.wait([firstConnect, secondConnect]);
    await socket.connect();
    expect(calls, 1);
    channel.incoming.add('{"value":22}');
    expect(await firstMessage, {'value': 22});
    expect(await secondMessage, {'value': 22});
  });

  test('snapshot readings are filtered per listener on the same connection',
      () async {
    final channel = FakeChannel();
    final socket = createSocket(channel);
    final sensors =
        SensorRepository(socket: socket, decodeMessage: decodeTestMessage);
    final all = sensors.watchSensorData().take(2).toList();
    final room = sensors.watchSensorData(roomId: 'living').first;
    final device = sensors.watchSensorData(deviceId: 'sensor-2').first;
    await sensors.connect();
    channel.incoming.add(jsonEncode({'event': 'unrelated'}));
    channel.incoming.add(jsonEncode({
      'event': 'test-readings',
      'readings': [
        {
          'deviceId': 'sensor-1',
          'roomId': 'living',
          'value': 0,
          'isOnline': true
        },
        {
          'deviceId': 'sensor-2',
          'roomId': 'kitchen',
          'value': null,
          'isOnline': false
        },
      ]
    }));
    expect((await all).length, 2);
    expect((await room).value, 0);
    final offline = await device;
    expect(offline.value, isNull);
    expect(offline.isOnline, isFalse);
  });

  test('a malformed frame reports an error and later readings still arrive',
      () async {
    final channel = FakeChannel();
    final socket = createSocket(channel);
    final errors = <Object>[];
    final valid = Completer<Map<String, dynamic>>();
    final subscription =
        socket.messages.listen(valid.complete, onError: errors.add);
    addTearDown(subscription.cancel);
    await socket.connect();
    channel.incoming.add('not JSON');
    channel.incoming.add('[]');
    channel.incoming.add(utf8.encode('{"value":23,"unit":"°C"}'));
    expect(await valid.future, {'value': 23, 'unit': '°C'});
    expect(errors.length, 2);
    expect(errors.every((error) => error is FormatException), isTrue);
  });

  test('no invented subscription is sent; sends wait for connection readiness',
      () async {
    final channel = FakeChannel(readyNow: false);
    final socket = createSocket(channel);
    final sent = <Object?>[];
    final subscription = channel.outgoing.stream.listen(sent.add);
    addTearDown(subscription.cancel);
    expect(() => socket.send({'test': true}), throwsStateError);
    final connecting = socket.connect();
    expect(() => socket.send({'test': true}), throwsStateError);
    channel.handshake.complete();
    await connecting;
    expect(sent, isEmpty);
    final sentMessage = channel.outgoing.stream.first;
    socket.send({'test-subscription': 'house-1'});
    expect(jsonDecode(await sentMessage as String),
        {'test-subscription': 'house-1'});
  });

  test('remote close exposes disconnected state and permits a fresh connection',
      () async {
    final channels = [FakeChannel(), FakeChannel()];
    var calls = 0;
    final socket = WebSocketService(
        endpoint: 'wss://example.com/test',
        connector: (uri) => channels[calls++]);
    addTearDown(socket.dispose);
    final states = <SocketConnectionState>[];
    final subscription = socket.connectionStates.listen(states.add);
    addTearDown(subscription.cancel);
    await socket.connect();
    await channels[0].incoming.close();
    expect(socket.state, SocketConnectionState.disconnected);
    await socket.connect();
    expect(calls, 2);
    expect(socket.state, SocketConnectionState.connected);
    expect(states, contains(SocketConnectionState.disconnected));
    await channels[0].outgoing.close();
  });

  test('failed handshake clears connecting state and surfaces the failure',
      () async {
    final channel = FakeChannel(readyNow: false);
    final socket = createSocket(channel);
    final result = expectLater(socket.connect(), throwsStateError);
    channel.handshake.completeError(StateError('Handshake failed'));
    await result;
    expect(socket.state, SocketConnectionState.disconnected);
  });

  test('handshake timeout cleans up the pending connection', () async {
    final channel = FakeChannel(readyNow: false);
    final socket = WebSocketService(
        endpoint: 'wss://example.com/test',
        connector: (uri) => channel,
        connectionTimeout: const Duration(milliseconds: 10));
    addTearDown(socket.dispose);
    await expectLater(socket.connect(), throwsA(isA<TimeoutException>()));
    expect(socket.state, SocketConnectionState.disconnected);
    channel.handshake.complete();
  });

  test('a cancelled old handshake cannot overwrite a new connection', () async {
    final channels = [FakeChannel(readyNow: false), FakeChannel()];
    var calls = 0;
    final socket = WebSocketService(
        endpoint: 'wss://example.com/test',
        connector: (uri) => channels[calls++]);
    addTearDown(socket.dispose);
    final cancelled = expectLater(socket.connect(), throwsStateError);
    await socket.disconnect();
    await socket.connect();
    channels[0].handshake.complete();
    await cancelled;
    expect(socket.state, SocketConnectionState.connected);
    final next = socket.messages.first;
    channels[1].incoming.add('{"still":"connected"}');
    expect(await next, {'still': 'connected'});
  });

  test('dispose closes consumers and prevents further connections or sends',
      () async {
    final channel = FakeChannel();
    final socket = createSocket(channel);
    final done = Completer<void>();
    final subscription = socket.messages.listen((_) {}, onDone: done.complete);
    addTearDown(subscription.cancel);
    await socket.connect();
    await socket.dispose();
    await done.future;
    await expectLater(socket.connect(), throwsStateError);
    expect(() => socket.send({'test': true}), throwsStateError);
  });
}
