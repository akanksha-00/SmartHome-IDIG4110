import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/notifications/notification_model.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/notification_repository.dart';
import 'package:smart_home/src/repositories/sensor_repository.dart';

Map<String, Object?> deviceJson({String type = 'fan'}) => {
      'id': 'device-1',
      'name': 'Living room device',
      'type': type,
      'house_id': 'house-1',
      'room_id': 'living',
      'manufacturer': 'Example manufacturer',
      'model': 'Model A',
      'manufactured_year': 2025,
      'installed_year': 2026,
      'installer': 'Alex',
      'capabilities': {
        'power': {'type': 'boolean'},
        'speed': {'type': 'integer', 'min': 0, 'max': 5},
      },
      'state': {'power': false, 'speed': 4},
      'status': {'online': false},
    };

http.Response jsonResponse(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

ApiClient mockedApi(FutureOr<http.Response> Function(http.Request) handler) {
  final api =
      ApiClient(client: MockClient((request) async => handler(request)));
  addTearDown(api.close);
  return api;
}

DeviceRepository devicesWith(ApiClient api) =>
    DeviceRepository(apiClient: api, houseId: 'house-1');

void main() {
  test('house device route preserves complete generic API records', () async {
    final api = mockedApi((request) {
      expect(request.method, 'GET');
      expect(request.url.toString(),
          '${ApiEndpoints.baseUrl}/api/v1/houses/house-1/devices');
      return jsonResponse([deviceJson()]);
    });
    final device = (await devicesWith(api).fetchDevices()).single;
    expect(device.name, 'Living room device');
    expect(device.houseId, 'house-1');
    expect(device.roomId, 'living');
    expect(device.state, {'power': false, 'speed': 4});
    expect(device.status, {'online': false});
    expect(device.capabilities['speed']?.max, 5);
    expect(device.manufacturedYear, 2025);
    expect(device.installer, 'Alex');
  });

  test('room filtering uses the dedicated room route, not a query', () async {
    final api = mockedApi((request) {
      expect(request.url.path, '/api/v1/houses/house-1/rooms/living/devices');
      expect(request.url.queryParameters, isEmpty);
      return jsonResponse([]);
    });
    expect(await devicesWith(api).fetchDevices(roomId: 'living'), isEmpty);
  });

  test('house and device IDs stay within their own path segments', () async {
    final api = mockedApi((request) {
      expect(request.url.pathSegments,
          ['api', 'v1', 'houses', 'house/a ?', 'devices', 'device/1 ?']);
      expect(request.url.queryParameters, isEmpty);
      return jsonResponse(deviceJson());
    });
    await DeviceRepository(apiClient: api, houseId: 'house/a ?')
        .fetchDeviceStatus('device/1 ?');
    expect(Uri.parse(ApiEndpoints.roomDevices('h/a', 'r/b')).pathSegments,
        ['api', 'v1', 'houses', 'h/a', 'rooms', 'r/b', 'devices']);
  });

  test('unassigned custom device types do not become living-room devices',
      () async {
    final api = mockedApi((request) => jsonResponse({
          'id': 'sensor-1',
          'name': 'Temperature sensor',
          'type': 'temperature_sensor',
          'house_id': 'house-1',
          'room_id': null,
        }));
    final result = await devicesWith(api).fetchDeviceStatus('sensor-1');
    expect(result.type, 'temperature_sensor');
    expect(result.roomId, isNull);
    expect(result.state, isEmpty);
    expect(result.status, isEmpty);
    expect(result.capabilities, isEmpty);
  });

  test('create uses supplied ID, snake_case fields, and capability metadata',
      () async {
    final api = mockedApi((request) {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/houses/house-1/devices');
      expect(jsonDecode(request.body), {
        'id': 'device-1',
        'name': 'New fan',
        'type': 'fan',
        'room_id': 'living',
        'manufactured_year': 2025,
        'capabilities': {
          'speed': {'type': 'integer', 'min': 0, 'max': 5}
        },
        'state': {'speed': 0},
        'status': {},
      });
      return jsonResponse(deviceJson(), 201);
    });
    final result = await devicesWith(api).addDevice(
      id: 'device-1',
      name: ' New fan ',
      type: 'fan',
      roomId: 'living',
      manufacturedYear: 2025,
      capabilities: {
        'speed': const DeviceCapability(type: 'integer', min: 0, max: 5)
      },
      state: {'speed': 0},
    );
    expect(result.id, 'device-1');
  });

  test('creating an unassigned device does not send room or UI-only fields',
      () async {
    final api = mockedApi((request) {
      final body = jsonDecode(request.body) as Map;
      expect(body.containsKey('room_id'), isFalse);
      expect(body.containsKey('title'), isFalse);
      expect(body.containsKey('subtitle'), isFalse);
      return jsonResponse(deviceJson(), 201);
    });
    await devicesWith(api).addDevice(id: 'd', name: 'Sensor', type: 'sensor');
  });

  test('PATCH sends an array of capabilities, retaining false and zero',
      () async {
    final api = mockedApi((request) {
      expect(request.method, 'PATCH');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), [
        {'name': 'power', 'value': false},
        {'name': 'brightness', 'value': 0},
        {'name': 'speed', 'value': 4},
      ]);
      return jsonResponse(deviceJson());
    });
    final result = await devicesWith(api).updateDevice(
      id: 'device-1',
      updates: {'power': false, 'brightness': 0, 'speed': 4},
    );
    expect(result.state['speed'], 4);
  });

  test('empty identifiers and commands fail before requests', () async {
    var calls = 0;
    final api = mockedApi((request) {
      calls++;
      return jsonResponse(deviceJson());
    });
    expect(() => DeviceRepository(apiClient: api, houseId: ''),
        throwsArgumentError);
    final repo = devicesWith(api);
    await expectLater(
        repo.updateDevice(id: 'd', updates: {}), throwsArgumentError);
    await expectLater(repo.updateDevice(id: '', updates: {'power': true}),
        throwsArgumentError);
    await expectLater(
        repo.updateDevice(id: 'd', updates: {' ': 1}), throwsArgumentError);
    await expectLater(repo.fetchDeviceStatus(''), throwsArgumentError);
    await expectLater(repo.fetchDevices(roomId: ''), throwsArgumentError);
    await expectLater(
        repo.addDevice(id: '', name: 'X', type: 'fan'), throwsArgumentError);
    expect(calls, 0);
  });

  test('HTTP errors are exposed rather than converted to empty results',
      () async {
    final repo =
        devicesWith(mockedApi((request) => http.Response('Unavailable', 503)));
    await expectLater(
        repo.fetchDevices(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 503),
        ));
  });

  test('HTTP validation failures on PATCH are preserved', () async {
    final repo = devicesWith(mockedApi(
        (request) => jsonResponse({'detail': 'Invalid capability'}, 422)));
    await expectLater(
        repo.updateDevice(id: 'd', updates: {'unknown': true}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422),
        ));
  });

  test('invalid JSON and missing required API fields are rejected', () async {
    for (final response in [
      http.Response('not JSON', 200),
      jsonResponse([
        {'id': 'd'}
      ]),
      jsonResponse([
        {...deviceJson(), 'state': null}
      ]),
      jsonResponse([
        {...deviceJson(), 'installed_year': '2026'}
      ]),
    ]) {
      final repo = devicesWith(mockedApi((request) => response));
      await expectLater(repo.fetchDevices(), throwsFormatException);
    }
  });

  test('missing feed endpoints cannot contact guessed server routes', () async {
    var calls = 0;
    final api = mockedApi((request) {
      calls++;
      return jsonResponse([]);
    });
    expect(ApiEndpoints.sensorData, isNull);
    expect(ApiEndpoints.notifications, isNull);
    await expectLater(SensorRepository(apiClient: api).fetchSensorData(),
        throwsUnsupportedError);
    await expectLater(
        NotificationRepository(apiClient: api).fetchNotifications(),
        throwsUnsupportedError);
    expect(calls, 0);
  });

  test(
      'draft sensor parser preserves offline null and zero when explicitly configured',
      () async {
    final api = mockedApi((request) {
      final record = {
        'id': 'r',
        'deviceId': 's',
        'roomId': 'living',
        'type': 'occupancy',
        'value': 0,
        'isOnline': true,
        'recordedAt': '2026-10-08T10:00:00Z'
      };
      return jsonResponse([
        record,
        {...record, 'value': null, 'isOnline': false, 'recordedAt': null}
      ]);
    });
    final values = await SensorRepository(
            apiClient: api, endpoint: 'https://example.com/test-readings')
        .fetchSensorData();
    expect(values[0].value, 0);
    expect(values[0].recordedAt, DateTime.utc(2026, 10, 8, 10));
    expect(values[1].value, isNull);
    expect(values[1].isOnline, isFalse);
  });

  test('draft notification parser preserves unicode and alert severity',
      () async {
    final api = mockedApi((request) => jsonResponse([
          {
            'id': 'alert-1',
            'title': 'Room at 30°C',
            'message': 'Temperature is high',
            'severity': 'warning',
            'createdAt': '2026-10-08T10:00:00Z',
            'isRead': false
          },
        ]));
    final values = await NotificationRepository(
            apiClient: api, endpoint: 'https://example.com/test-feed')
        .fetchNotifications();
    expect(values.single.title, 'Room at 30°C');
    expect(values.single.severity, NotificationSeverity.warning);
  });

  test('transport errors propagate and supplied headers reach the client',
      () async {
    final api = ApiClient(
        headers: {'Authorization': 'Bearer test-token'},
        client: MockClient((request) {
          expect(request.headers['Authorization'], 'Bearer test-token');
          throw http.ClientException('Connection failed');
        }));
    addTearDown(api.close);
    await expectLater(api.get(ApiEndpoints.devices('h')),
        throwsA(isA<http.ClientException>()));
  });

  test('a timeout does not automatically resend a device command', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final api = ApiClient(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((request) {
          calls++;
          return response.future;
        }));
    addTearDown(api.close);
    await expectLater(
        api.patch(ApiEndpoints.device('h', 'd'), [
          {'name': 'power', 'value': true}
        ]),
        throwsA(isA<TimeoutException>()));
    expect(calls, 1);
    response.complete(jsonResponse(deviceJson()));
  });
}
