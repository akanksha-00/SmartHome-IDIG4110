import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
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

void main() {
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
    await loadDevices(bloc);
    await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
              appBar: AppBar(actions: const [
                DashboardNotifications(
                    roomNames: {'living-room': 'Living Room'})
              ]),
              body: BlocBuilder<DeviceBloc, DeviceState>(
                  builder: (context, state) => ApiDeviceCard(
                        device: state.devices.single,
                        subtitle: 'Living Room',
                        onStateChanged: (_) {},
                      ))),
        )));
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
    expect(bloc.state.unreadAlertCount, 1);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(bloc.state.unreadAlertCount, 0);
    expect(find.textContaining('Living Room · Active'), findsOneWidget);
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
    await loadDevices(bloc);
    await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(
            home: Scaffold(
          appBar: AppBar(actions: const [DashboardNotifications()]),
          body: BlocBuilder<DeviceBloc, DeviceState>(
              builder: (context, state) => ApiDeviceCard(
                    device: state.devices.single,
                    subtitle: 'Living Room',
                    onStateChanged: (_) {},
                  )),
        ))));
    await tester.pumpAndSettle();
    bloc.add(DeviceRealtimeReceived(
        DeviceMessage(deviceId: 'device-014', updates: {'temperature': 37.5})));
    await tester.pumpAndSettle();
    expect(find.textContaining('37.5°C'), findsOneWidget);
    expect(bloc.state.alerts, isEmpty);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No alerts received this session'), findsOneWidget);
  });
}
