import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/config/floor_plan_bindings.dart';

import 'helpers/device_test_data.dart' show jsonResponse;
import 'helpers/room_test_data.dart';

void main() {
  test('GET hydrates an immutable room list and backend names', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final bloc = testRoomBloc((request) {
      calls++;
      expect(request.method, 'GET');
      expect(request.url.toString(), ApiEndpoints.rooms(AppConfig.houseId));
      return response.future;
    });
    final loading = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.loading);
    bloc.add(const RoomsRequested());
    await loading;
    expect(bloc.state.hasLoaded, isFalse);
    final loaded = waitForRoomState(bloc, (state) => state.hasLoaded);
    response.complete(jsonResponse([
      roomJson(id: 'custom-room', name: 'Reading nook'),
      roomJson(id: 'bedroom', name: 'Bedroom 1'),
    ]));
    await loaded;
    expect(bloc.state.rooms, hasLength(2));
    expect(bloc.state.selectedRoomId, 'custom-room');
    expect(bloc.state.selectedRoom!.name, 'Reading nook');
    expect(() => bloc.state.rooms.clear(), throwsUnsupportedError);
    bloc.add(const RoomsRequested());
    bloc.add(const RoomSelected('bedroom'));
    await waitForRoomState(bloc, (state) => state.selectedRoomId == 'bedroom');
    expect(calls, 1);
  });

  test('failed load retries, and empty rooms is a loaded state', () async {
    var calls = 0;
    final bloc = testRoomBloc((_) async =>
        ++calls == 1 ? http.Response('Unavailable', 503) : jsonResponse([]));
    final failed = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.failed);
    bloc.add(const RoomsRequested());
    await failed;
    expect(bloc.state.loadError, isNotNull);
    expect(bloc.state.hasLoaded, isFalse);
    await loadRooms(bloc);
    expect(bloc.state.hasLoaded, isTrue);
    expect(bloc.state.rooms, isEmpty);
    expect(bloc.state.selectedRoom, isNull);
    expect(bloc.state.loadError, isNull);
  });

  test('refresh preserves valid selection and then applies queued clicks',
      () async {
    final refresh = Completer<http.Response>();
    var calls = 0;
    final records = [
      roomJson(),
      roomJson(id: 'bedroom', name: 'Guest bedroom')
    ];
    final bloc = testRoomBloc(
        (_) async => ++calls == 1 ? jsonResponse(records) : refresh.future);
    await loadRooms(bloc);
    final selected =
        waitForRoomState(bloc, (state) => state.selectedRoomId == 'bedroom');
    bloc.add(const RoomSelected('bedroom'));
    await selected;
    final loading = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.loading);
    bloc.add(const RoomsRequested(force: true));
    await loading;
    final loaded = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.loaded);
    final clicked = waitForRoomState(
        bloc, (state) => state.selectedRoomId == 'living-room');
    bloc.add(const RoomSelected('living-room'));
    refresh.complete(jsonResponse(records.reversed.toList()));
    final refreshed = await loaded;
    expect(refreshed.selectedRoomId, 'bedroom');
    await clicked;
    expect(bloc.state.selectedRoomId, 'living-room');
  });

  test('removed selections fall back to a returned room and then to null',
      () async {
    var records = [roomJson(), roomJson(id: 'bedroom')];
    final bloc = testRoomBloc((_) async => jsonResponse(records));
    await loadRooms(bloc);
    records = [roomJson(id: 'bedroom', name: 'Bedroom 1')];
    await loadRooms(bloc, force: true);
    expect(bloc.state.selectedRoomId, 'bedroom');
    records = [];
    await loadRooms(bloc, force: true);
    expect(bloc.state.selectedRoomId, isNull);
    expect(bloc.state.selectedRoom, isNull);
  });

  test('failed refresh keeps the last rooms and selection', () async {
    var calls = 0;
    final bloc = testRoomBloc((_) async => ++calls == 1
        ? jsonResponse([roomJson()])
        : http.Response('Unavailable', 503));
    await loadRooms(bloc);
    final failed = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.failed);
    bloc.add(const RoomsRequested(force: true));
    await failed;
    expect(bloc.state.hasLoaded, isTrue);
    expect(bloc.state.rooms.single.id, 'living-room');
    expect(bloc.state.selectedRoomId, 'living-room');
  });

  test('rooms without a GLB mesh remain selectable API records', () async {
    final bloc =
        testRoomBloc((_) async => jsonResponse([roomJson(id: 'custom-room')]));
    await loadRooms(bloc);
    expect(FloorPlanBindings.objectNameFor(bloc.state.selectedRoom!), isNull);
    final emissions = <RoomState>[];
    final subscription = bloc.stream.listen(emissions.add);
    bloc.add(const RoomSelected('missing-room'));
    await bloc.close();
    await subscription.cancel();
    expect(bloc.state.selectedRoomId, 'custom-room');
    expect(emissions, isEmpty);
  });

  test('malformed, foreign-house and duplicate rooms are rejected', () async {
    for (final records in [
      [
        {'id': 'r'}
      ],
      [
        {...roomJson(), 'house_id': 'different-house'}
      ],
      [roomJson(), roomJson()],
      [
        {...roomJson(), 'name': false}
      ],
      [roomJson(name: ' ')],
    ]) {
      final bloc = testRoomBloc((_) async => jsonResponse(records));
      await expectLater(bloc.repository.fetchRooms(), throwsFormatException);
    }
    expect(Uri.parse(ApiEndpoints.rooms('house/a ?')).pathSegments,
        ['api', 'v1', 'houses', 'house/a ?', 'rooms']);
  });

  test('duplicate requests do not overlap and close does not wait for HTTP',
      () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final bloc = testRoomBloc((_) {
      calls++;
      return response.future;
    });
    final loading = waitForRoomState(
        bloc, (state) => state.status == RoomLoadStatus.loading);
    bloc.add(const RoomsRequested());
    await loading;
    bloc.add(const RoomsRequested(force: true));
    await bloc.close().timeout(const Duration(seconds: 1));
    expect(calls, 1);
    response.complete(jsonResponse([roomJson()]));
  });
}
