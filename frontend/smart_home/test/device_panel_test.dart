import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/screen/home/widgets/addDeviceDialog.dart';
import 'package:smart_home/src/screen/home/widgets/api_device_card.dart';
import 'package:smart_home/src/screen/home/widgets/device_panel.dart';
import 'package:smart_home/src/screen/home/widgets/fanDeviceCard.dart';
import 'package:smart_home/src/theme/app_theme.dart';

import 'helpers/device_test_data.dart';

Widget panelHarness(DeviceBloc bloc,
        {String roomId = 'living-room', String roomName = 'Living Room'}) =>
    BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
              body: SizedBox(
                  width: 480,
                  child: DevicePanel(roomId: roomId, roomName: roomName))),
        ));

List<Map<String, Object?>> houseDevices() => [
      deviceJson(),
      deviceJson(
          id: 'device-002', name: 'Ceiling Fan', type: 'fan', power: true),
      deviceJson(
          id: 'device-003',
          name: 'Bedroom Fan',
          type: 'fan',
          roomId: 'bedroom'),
    ];

Future<void> openPanel(WidgetTester tester, DeviceBloc bloc) async {
  await loadDevices(bloc);
  await tester.pumpWidget(panelHarness(bloc));
  await tester.pumpAndSettle();
}

Finder cardSwitch(String id) => find.descendant(
    of: find.byKey(ValueKey(id)), matching: find.byType(Switch));

void main() {
  testWidgets(
      'fetched devices, room counts, search and categories use BLoC data',
      (tester) async {
    final bloc = testDeviceBloc((_) async => jsonResponse(houseDevices()));
    await openPanel(tester, bloc);
    expect(find.text('2 devices · 1 on'), findsOneWidget);
    expect(find.text('Ceiling Light'), findsOneWidget);
    expect(find.text('Bedroom Fan'), findsNothing);
    await tester.tap(find.text('Fans'));
    await tester.pumpAndSettle();
    expect(find.text('Ceiling Fan'), findsOneWidget);
    expect(find.text('Ceiling Light'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('device-search')), 'missing');
    await tester.pumpAndSettle();
    expect(
        find.text('No devices match your search or category'), findsOneWidget);
    await tester.pumpWidget(
        panelHarness(bloc, roomId: 'bedroom', roomName: 'Bedroom 1'));
    await tester.pumpAndSettle();
    expect(find.text('Bedroom Fan'), findsOneWidget);
    expect(find.text('All  1'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('device-search')))
            .controller!
            .text,
        isEmpty);
    expect(bloc.state.devices, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'switch sends a PATCH, stays disabled while pending, then rolls back on failure',
      (tester) async {
    final response = Completer<http.Response>();
    var writes = 0;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse(houseDevices());
      writes++;
      expectSync(jsonDecode(request.body), [
        {'name': 'power', 'value': true}
      ]);
      return response.future;
    });
    await openPanel(tester, bloc);
    await tester.tap(cardSwitch('device-001'));
    await tester.pump();
    expect(tester.widget<Switch>(cardSwitch('device-001')).value, isTrue);
    expect(tester.widget<Switch>(cardSwitch('device-001')).onChanged, isNull);
    response.complete(http.Response('Unavailable', 503));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(cardSwitch('device-001')).value, isFalse);
    expect(
        tester.widget<Switch>(cardSwitch('device-001')).onChanged, isNotNull);
    expect(find.textContaining('Could not update devices'), findsOneWidget);
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fan renders and sends all speeds declared by the API',
      (tester) async {
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse(houseDevices());
      expectSync(jsonDecode(request.body), [
        {'name': 'speed', 'value': 5}
      ]);
      return jsonResponse(deviceJson(
          id: 'device-002',
          name: 'Ceiling Fan',
          type: 'fan',
          power: true,
          speed: 5));
    });
    await openPanel(tester, bloc);
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    final fan = tester.widget<FanDeviceCard>(find.byType(FanDeviceCard));
    expect(fan.speed, 5);
    expect(fan.speedValues, [1, 2, 3, 4, 5]);
    expect(bloc.state.devices[1].state['speed'], 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'brightness previews locally and sends one scaled PATCH when the drag ends',
      (tester) async {
    var writes = 0;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') {
        return jsonResponse([deviceJson(power: true)]);
      }
      writes++;
      expectSync(jsonDecode(request.body), [
        {'name': 'brightness', 'value': 60}
      ]);
      return jsonResponse(deviceJson(power: true, brightness: 60));
    });
    await openPanel(tester, bloc);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.4);
    slider.onChanged!(0.5);
    slider.onChanged!(0.6);
    await tester.pump();
    expect(writes, 0);
    expect(bloc.state.devices.single.state['brightness'], 40);
    slider.onChangeEnd!(0.6);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(bloc.state.updateError, isNull);
    expect(bloc.state.devices.single.state['brightness'], 60);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.6);
  });

  testWidgets(
      'unknown and unassigned types do not crash or appear in the wrong room',
      (tester) async {
    final bloc = testDeviceBloc((_) async => jsonResponse([
          deviceJson(type: 'custom_device', name: 'Custom Device'),
          deviceJson(id: 'unassigned', name: 'Unassigned', roomId: null),
        ]));
    await openPanel(tester, bloc);
    expect(find.text('Custom Device'), findsOneWidget);
    expect(find.text('Unassigned'), findsNothing);
    expect(find.byType(ApiDeviceCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Add validates, assigns the selected API room, and closes only after POST success',
      (tester) async {
    final response = Completer<http.Response>();
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse(houseDevices());
      expectSync(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expectSync(body['room_id'], 'living-room');
      expectSync(body['id'], 'device-new');
      expectSync(body['capabilities']['brightness']['max'], 100);
      return response.future;
    });
    await openPanel(tester, bloc);
    await tester.tap(find.text('Add Device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a device name'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('add-device-name')), 'New light');
    await tester.enterText(
        find.byKey(const ValueKey('add-device-id')), 'device-new');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.byType(AddDeviceDialog), findsOneWidget);
    expect(find.text('Adding…'), findsOneWidget);
    expect(bloc.state.devices, hasLength(3));
    response.complete(
        jsonResponse(deviceJson(id: 'device-new', name: 'New light')));
    await tester.pumpAndSettle();
    expect(find.byType(AddDeviceDialog), findsNothing);
    expect(bloc.state.devices, hasLength(4));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('device-new')),
      100,
      scrollable: find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('New light'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed Add retains the form and supports retry', (tester) async {
    var writes = 0;
    final bloc = testDeviceBloc((request) async {
      if (request.method == 'GET') return jsonResponse(houseDevices());
      writes++;
      return writes == 1
          ? http.Response('Unavailable', 503)
          : jsonResponse(deviceJson(id: 'device-new', name: 'New light'));
    });
    await openPanel(tester, bloc);
    await tester.tap(find.text('Add Device'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('add-device-name')), 'New light');
    await tester.enterText(
        find.byKey(const ValueKey('add-device-id')), 'device-new');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AddDeviceDialog), findsOneWidget);
    expect(find.textContaining('Could not add device'), findsOneWidget);
    expect(bloc.state.devices, hasLength(3));
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('add-device-name')))
            .controller!
            .text,
        'New light');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AddDeviceDialog), findsNothing);
    expect(writes, 2);
  });

  test('floor-plan aliases preserve the API room IDs and unknown IDs', () {
    expect(AppConfig.deviceRoomId('living'), 'living-room');
    expect(AppConfig.deviceRoomId('bedroom1'), 'bedroom');
    expect(AppConfig.deviceRoomId('future-room'), 'future-room');
  });
}
