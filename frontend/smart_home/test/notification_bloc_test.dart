import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

import 'helpers/fake_web_socket.dart';
import 'helpers/notification_test_data.dart';

void main() {
  test('starts empty and does not infer alerts from values or ordinary events',
      () async {
    final bloc = testNotificationBloc();
    expect(bloc.state.notifications, isEmpty);
    bloc.add(NotificationReceived(
        DeviceMessage(deviceId: 'device-014', updates: {'temperature': 80})));
    bloc.add(NotificationReceived(alertMessage(alert: false, value: false)));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.notifications, isEmpty);
    expect(bloc.state.unreadCount, 0);
  });

  test('deduplicates active alerts and allows a new incident after clearing',
      () async {
    final bloc = testNotificationBloc();
    final first = await notify(bloc, NotificationReceived(alertMessage()));
    expect(first.unreadCount, 1);
    expect(first.notifications.single.message, 'smoke detected in bedroom!');
    expect(first.notifications.single.deviceId, 'device-013');
    expect(() => first.notifications.clear(), throwsUnsupportedError);
    bloc.add(NotificationReceived(alertMessage()));
    bloc.add(
        NotificationReceived(alertMessage(event: 'unrelated', alert: false)));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, same(first));
    await notify(bloc, const NotificationRead(1));
    final cleared = await notify(
        bloc,
        NotificationReceived(
            alertMessage(alert: false, value: false, message: null)));
    expect(cleared.notifications.single.isActive, isFalse);
    expect(cleared.notifications.single.isRead, isTrue);
    expect(first.notifications.single.isActive, isTrue);
    final next = await notify(bloc, NotificationReceived(alertMessage()));
    expect(next.notifications, hasLength(2));
    expect(next.latestSequence, 2);
    expect(next.unreadCount, 1);
    expect(next.notifications.last.isActive, isFalse);
  });

  test('read actions preserve alert content and ignore missing/repeated IDs',
      () async {
    final bloc = testNotificationBloc();
    await notify(bloc, NotificationReceived(alertMessage()));
    final before = await notify(
        bloc,
        NotificationReceived(alertMessage(
            deviceId: 'device-014',
            event: 'temperature',
            value: 35,
            message: 'Temperature is 35°C')));
    final read = await notify(bloc, const NotificationRead(1));
    expect(read.unreadCount, 1);
    expect(read.notifications.last.isRead, isTrue);
    expect(before.notifications.last.isRead, isFalse);
    final allRead = await notify(bloc, const NotificationsReadAll());
    expect(allRead.unreadCount, 0);
    expect(allRead.notifications.first.value, 35);
    expect(allRead.notifications.first.isActive, isTrue);
    bloc.add(const NotificationRead(999));
    bloc.add(const NotificationRead(1));
    bloc.add(const NotificationsReadAll());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, same(allRead));
  });

  test('retains at most 50 incidents and uses IDs when backend text is absent',
      () async {
    final bloc = testNotificationBloc();
    for (var index = 1; index <= 60; index++) {
      await notify(
          bloc,
          NotificationReceived(
              alertMessage(deviceId: 'test-device-$index', message: null)));
    }
    expect(bloc.state.notifications, hasLength(50));
    expect(bloc.state.latestSequence, 60);
    expect(bloc.state.notifications.last.sequence, 11);
    expect(
        bloc.state.notifications.first.message, 'test-device-60: smoke alert');
    expect(bloc.state.unreadCount, 50);
  });

  test(
      'shares the socket, keeps history on parse errors and only cancels its listener',
      () async {
    final channel = FakeChannel();
    var connections = 0;
    final realtime = HouseRealtimeRepository(
        socket: WebSocketService(
            endpoint: 'ws://localhost/ws',
            connector: (_) {
              connections++;
              return channel;
            }));
    addTearDown(realtime.dispose);
    final bloc = testNotificationBloc(realtime: realtime);
    expect(
        connections, 0); // NotificationBloc must not start a second connection.
    final connected = realtime.connectionStates
        .firstWhere((s) => s == SocketConnectionState.connected);
    realtime.start();
    await connected;
    final received = waitForNotificationState(bloc, (s) => s.unreadCount == 1);
    channel.incoming.add(jsonEncode(alertJson()));
    await received;
    channel.incoming.add('invalid JSON');
    final cleared =
        waitForNotificationState(bloc, (s) => !s.notifications.single.isActive);
    channel.incoming
        .add(jsonEncode(alertJson(alert: false, value: false, message: null)));
    await cleared;
    await bloc.close();
    final nextMessage = realtime.messages.first;
    channel.incoming.add(jsonEncode(alertJson()));
    expect((await nextMessage).alert, isTrue);
    expect(realtime.connectionState, SocketConnectionState.connected);
    expect(connections, 1);
  });
}
