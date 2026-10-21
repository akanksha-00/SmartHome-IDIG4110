import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/main.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/screen/home/homePage.dart';
import 'package:smart_home/src/screen/home/widgets/addDeviceDialog.dart';
import 'package:smart_home/src/screen/home/widgets/device_panel.dart';
import 'package:smart_home/src/screen/home/widgets/room_selector.dart';
import 'package:smart_home/src/widgets/room_startup_gate.dart';

import 'helpers/device_test_data.dart';
import 'helpers/room_test_data.dart';

Widget selectorHarness(RoomBloc rooms, DeviceBloc devices) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: rooms),
        BlocProvider.value(value: devices)
      ],
      child: MaterialApp(
          home: Scaffold(
              body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) => Row(children: [
          const RoomSelector(),
          Expanded(
              child: DevicePanel(
                  roomId: state.selectedRoom!.id,
                  roomName: state.selectedRoom!.name)),
        ]),
      ))),
    );

Future<void> disposeRoomHarness(WidgetTester tester, RoomBloc rooms) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // BLoC stream cleanup needs the real async clock, outside fake widget time.
  await tester.runAsync(rooms.close);
}

void main() {
  testWidgets(
      'API room names drive dropdown, device filtering and Add assignment',
      (tester) async {
    final rooms = testRoomBloc((_) async => jsonResponse([
          roomJson(id: 'reading-nook', name: 'Reading nook'),
          roomJson(id: 'guest-room', name: 'Guest bedroom'),
        ]));
    final devices = testDeviceBloc((_) async => jsonResponse([
          deviceJson(name: 'Nook light', roomId: 'reading-nook'),
          deviceJson(
              id: 'device-002', name: 'Guest light', roomId: 'guest-room'),
        ]));
    await loadRooms(rooms);
    await loadDevices(devices);
    await tester.pumpWidget(selectorHarness(rooms, devices));
    await tester.pumpAndSettle();
    final menu =
        tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
    expect(menu.dropdownMenuEntries.map((entry) => entry.label),
        ['Reading nook', 'Guest bedroom']);
    expect(menu.initialSelection, 'reading-nook');
    expect(find.text('Nook light'), findsOneWidget);
    expect(find.text('Guest light'), findsNothing);
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest bedroom').last);
    await tester.pumpAndSettle();
    expect(rooms.state.selectedRoomId, 'guest-room');
    expect(find.text('Nook light'), findsNothing);
    expect(find.text('Guest light'), findsOneWidget);
    await tester.tap(find.text('Add Device'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<AddDeviceDialog>(find.byType(AddDeviceDialog));
    expect(dialog.roomId, 'guest-room');
    expect(dialog.roomName, 'Guest bedroom');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    rooms
        .add(const RoomSelected('reading-nook')); // Same event as a mesh click.
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>))
            .initialSelection,
        'reading-nook');
    expect(find.text('Nook light'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeRoomHarness(tester, rooms);
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('empty room list shows Home empty state and can refresh',
      (tester) async {
    var calls = 0;
    final rooms = testRoomBloc((_) async {
      calls++;
      return jsonResponse([]);
    });
    await loadRooms(rooms);
    await tester.pumpWidget(BlocProvider.value(
      value: rooms,
      child: const MaterialApp(home: Scaffold(body: HomePage())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No rooms configured for this house'), findsOneWidget);
    await tester.tap(find.text('Refresh rooms'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    await disposeRoomHarness(tester, rooms);
  });

  testWidgets('failed rooms startup retries without fallback room data',
      (tester) async {
    var calls = 0;
    final rooms = testRoomBloc((_) async =>
        ++calls == 1 ? http.Response('Unavailable', 503) : jsonResponse([]));
    rooms.add(const RoomsRequested());
    await tester.pumpWidget(BlocProvider.value(
      value: rooms,
      child:
          const MaterialApp(home: RoomStartupGate(child: Text('Rooms loaded'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Could not load rooms'), findsOneWidget);
    expect(find.text('Rooms loaded'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Rooms loaded'), findsOneWidget);
    expect(calls, 2);
    await disposeRoomHarness(tester, rooms);
  });

  testWidgets('MyApp loads rooms alongside devices and waits for both',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final roomResponse = Completer<http.Response>();
    final deviceResponse = Completer<http.Response>();
    var roomCalls = 0;
    var deviceCalls = 0;
    final source = testDeviceBloc((request) {
      if (request.url.path.endsWith('/rooms')) {
        roomCalls++;
        return roomResponse.future;
      }
      deviceCalls++;
      return deviceResponse.future;
    });
    await tester.pumpWidget(MyApp(deviceRepository: source.repository));
    await tester.pump();
    expect(roomCalls, 1);
    expect(deviceCalls, 1);
    expect(find.text('Loading devices…'), findsOneWidget);
    deviceResponse.complete(jsonResponse([]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Loading rooms…'), findsOneWidget);
    roomResponse.complete(jsonResponse([]));
    await tester.pumpAndSettle();
    expect(find.text('No rooms configured for this house'), findsOneWidget);
    expect(find.text('Loading rooms…'), findsNothing);
    await tester.pumpWidget(MyApp(deviceRepository: source.repository));
    await tester.pumpAndSettle();
    expect(roomCalls, 1);
    expect(deviceCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
