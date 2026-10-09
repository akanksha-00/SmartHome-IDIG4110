import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';

Map<String, Object?> deviceJson({
  String id = 'device-001',
  String name = 'Ceiling Light',
  String type = 'light',
  String? roomId = 'living-room',
  bool power = false,
  int brightness = 40,
  int speed = 3,
}) =>
    {
      'id': id,
      'name': name,
      'type': type,
      'house_id': AppConfig.houseId,
      'room_id': roomId,
      'capabilities': {
        'power': {'type': 'boolean'},
        if (type == 'light')
          'brightness': {'type': 'integer', 'min': 0, 'max': 100},
        if (type == 'fan') 'speed': {'type': 'integer', 'min': 1, 'max': 5},
      },
      'state': {
        'power': power,
        if (type == 'light') 'brightness': brightness,
        if (type == 'fan') 'speed': speed,
      },
      'status': {'operational': true},
    };

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

DeviceBloc testDeviceBloc(Future<http.Response> Function(http.Request) handler,
    {HouseRealtimeRepository? realtime}) {
  final client = ApiClient(client: MockClient(handler));
  final bloc = DeviceBloc(
      realtime: realtime,
      repository: DeviceRepository(
        apiClient: client,
        houseId: AppConfig.houseId,
      ));
  addTearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    client.close();
  });
  return bloc;
}

Future<DeviceState> waitForDeviceState(
        DeviceBloc bloc, bool Function(DeviceState) matches) =>
    bloc.stream.firstWhere(matches).timeout(const Duration(seconds: 3));

Future<void> loadDevices(DeviceBloc bloc) async {
  final loaded = waitForDeviceState(
      bloc, (state) => state.status == DeviceLoadStatus.loaded);
  bloc.add(const DevicesRequested());
  await loaded;
}

Map<String, Object?> sensorJson(
        String id, String type, String key, Object value) =>
    {
      ...deviceJson(id: id, type: type),
      'capabilities': {
        key: {'type': key == 'smoke' ? 'boolean' : 'number'}
      },
      'state': {key: value},
    };
