import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/screen/dashboard/dashboard_notifications.dart';
import 'package:smart_home/src/screen/home/widgets/api_device_card.dart';
import 'package:smart_home/src/theme/app_theme.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';
import 'package:smart_home/src/screen/home/widgets/room_environment_card.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

import 'helpers/device_test_data.dart';
import 'helpers/fake_web_socket.dart';
import 'helpers/notification_test_data.dart';

Widget notificationHarness(DeviceBloc devices, NotificationBloc notifications,
        {Widget? body}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: devices),
        BlocProvider.value(value: notifications),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          appBar: AppBar(actions: const [
            DashboardNotifications(roomNames: {'living-room': 'Living Room'})
          ]),
          body: body,
        ),
      ),
    );

Badge notificationBadge(WidgetTester tester) =>
    tester.widget<Badge>(find.descendant(
        of: find.byKey(const ValueKey('app-bar-notifications')),
        matching: find.byType(Badge)));

void main() {
  testWidgets('received alerts can be read individually and all at once',
      (tester) async {
    var requests = 0;
    final devices = testDeviceBloc((_) async {
      requests++;
      return jsonResponse([]);
    });
    final notifications = testNotificationBloc();
    for (var index = 1; index <= 3; index++) {
      notifications.add(
          NotificationReceived(alertMessage(deviceId: 'test-device-$index')));
    }
    await tester.pumpWidget(notificationHarness(devices, notifications));
    await tester.pumpAndSettle();
    expect(notificationBadge(tester).isLabelVisible, isTrue);
    expect((notificationBadge(tester).label! as Text).data, '3');
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Demo notifications'), findsNothing);
    expect(find.text('3 unread'), findsOneWidget);
    expect(find.text('Device alerts'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification-3')));
    await tester.pumpAndSettle();
    expect(find.text('2 unread'), findsOneWidget);
    expect(notifications.state.notifications.first.isRead, isTrue);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);
    expect(notificationBadge(tester).isLabelVisible, isFalse);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);
    expect(notifications.state.notifications, hasLength(3));
    expect(requests, 0); // Reading the feed never calls a service or API.
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 600), const Size(1100, 540)]) {
    testWidgets('notification dialog fits ${size.width} x ${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final devices = testDeviceBloc((_) async => jsonResponse([]));
      final notifications = testNotificationBloc();
      for (var index = 1; index <= 5; index++) {
        notifications.add(
            NotificationReceived(alertMessage(deviceId: 'test-device-$index')));
      }
      await tester.pumpWidget(notificationHarness(devices, notifications));
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      final lastItem = find.byKey(const ValueKey('notification-1'));
      await tester.scrollUntilVisible(lastItem, 150);
      expect(lastItem, findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'room environment uses live readings for its selected room and temperature units',
      (tester) async {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    final bloc = testDeviceBloc((_) async => jsonResponse(
        [sensorJson('device-014', 'temperature_sensor', 'temperature', 35)]));
    await loadDevices(bloc);
    Widget harness(String roomId) => AppSettingsScope(
        controller: settings,
        child: BlocProvider.value(
            value: bloc,
            child: MaterialApp(
                home: Scaffold(body: RoomEnvironmentCard(roomId: roomId)))));
    await tester.pumpWidget(harness('living-room'));
    await tester.pumpAndSettle();
    expect(find.text('35.0°C'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-014', updates: {'temperature': 37.5})));
    await tester.pumpAndSettle();
    expect(find.text('37.5°C'), findsOneWidget);
    settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    await tester.pumpAndSettle();
    expect(find.text('99.5°F'), findsOneWidget);
    await tester.pumpWidget(harness('bedroom'));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('99.5°F'), findsNothing);
  });

  testWidgets(
      'a backend smoke event updates the sensor, shows an alert and unread badge, then opens history',
      (tester) async {
    final channel = FakeChannel();
    final realtime = HouseRealtimeRepository(
        socket: WebSocketService(
            endpoint: 'ws://localhost/ws', connector: (_) => channel));
    final bloc = testDeviceBloc(
        (_) async => jsonResponse([
              sensorJson('device-013', 'smoke_detector', 'smoke', false),
            ]),
        realtime: realtime);
    final notifications = testNotificationBloc(realtime: realtime);
    await loadDevices(bloc);
    await tester.pumpWidget(notificationHarness(bloc, notifications,
        body: BlocBuilder<DeviceBloc, DeviceState>(
            builder: (context, state) => ApiDeviceCard(
                  device: state.devices.single,
                  subtitle: 'Living Room',
                  onStateChanged: (_) {},
                ))));
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsOneWidget);
    expect(find.textContaining('No smoke detected'), findsOneWidget);
    channel.incoming.add(jsonEncode({
      'type': 'device_event',
      'device_id': 'device-013',
      'event': 'smoke',
      'value': true,
      'alert': true,
      'notification_message': 'smoke detected in bedroom!'
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Smoke detected'), findsOneWidget);
    expect(find.text('smoke detected in bedroom!'), findsOneWidget);
    expect(notifications.state.unreadCount, 1);
    expect((notificationBadge(tester).label! as Text).data, '1');
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(notifications.state.unreadCount, 1);
    expect((notificationBadge(tester).label! as Text).data, '1');
    expect(find.textContaining('Living Room · Active'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(notificationBadge(tester).isLabelVisible, isFalse);
    channel.incoming.add(jsonEncode({
      'type': 'device_event',
      'device_id': 'device-013',
      'event': 'smoke',
      'value': false,
      'alert': false,
      'notification_message': null
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Living Room · Cleared'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No smoke detected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ordinary temperature reports update readings without creating alerts',
      (tester) async {
    final bloc = testDeviceBloc((_) async => jsonResponse([
          sensorJson('device-014', 'temperature_sensor', 'temperature', 35),
        ]));
    final notifications = testNotificationBloc();
    await loadDevices(bloc);
    await tester.pumpWidget(notificationHarness(bloc, notifications,
        body: BlocBuilder<DeviceBloc, DeviceState>(
            builder: (context, state) => ApiDeviceCard(
                  device: state.devices.single,
                  subtitle: 'Living Room',
                  onStateChanged: (_) {},
                ))));
    await tester.pumpAndSettle();
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-014', updates: {'temperature': 37.5})));
    await tester.pumpAndSettle();
    expect(find.textContaining('37.5°C'), findsOneWidget);
    expect(notifications.state.notifications, isEmpty);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications to show'), findsOneWidget);
  });
}
