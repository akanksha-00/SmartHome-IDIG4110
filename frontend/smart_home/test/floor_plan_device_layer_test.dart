import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/config/floor_plan_bindings.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/rooms/api_room.dart';
import 'package:smart_home/src/screen/home/widgets/floor_plan_device_layer.dart';
import 'package:three_js/three_js.dart' as three;

ApiDevice device({
  String id = 'light-1',
  String type = 'light',
  String? roomId = 'living-room',
  bool power = true,
  num brightness = 50,
  int speed = 1,
  bool operational = true,
  num brightnessMin = 0,
  num brightnessMax = 100,
}) =>
    ApiDevice(
      id: id,
      name: id,
      type: type,
      houseId: 'house-001',
      roomId: roomId,
      capabilities: {
        'power': const DeviceCapability(type: 'boolean'),
        'brightness': DeviceCapability(
            type: 'integer', min: brightnessMin, max: brightnessMax),
        'speed': const DeviceCapability(type: 'integer', min: 1, max: 3),
      },
      state: {'power': power, 'brightness': brightness, 'speed': speed},
      status: {'operational': operational},
    );

const room = ApiRoom(id: 'living-room', houseId: 'house-001', name: 'Room');

three.Mesh floor(double width, double depth, double x, double z) => three.Mesh(
      three.PlaneGeometry(width, depth),
      three.MeshBasicMaterial.fromMap({'side': three.DoubleSide}),
    )
      ..rotation.x = -math.pi / 2
      ..position.setValues(x, 0, z);

three.Group house({bool irregular = false}) {
  final root = three.Group();
  final surface = three.Group()..name = 'livingRoom';
  if (irregular) {
    // An L-shaped floor with a missing upper-right quadrant.
    surface.add(floor(2, 4, -1, 0));
    surface.add(floor(2, 2, 1, 1));
  } else {
    surface.add(floor(4, 4, 0, 0));
  }
  root.add(surface);
  return root;
}

ApiDevice sensor({
  required String type,
  required Map<String, Object?> state,
  String id = 'sensor',
  String roomId = 'bedroom',
  bool operational = true,
}) =>
    ApiDevice(
      id: id,
      name: id,
      type: type,
      houseId: 'house-001',
      roomId: roomId,
      state: state,
      status: {'operational': operational},
    );

void main() {
  test(
      'asset bindings use API IDs and stay house-specific without API metadata',
      () {
    const apiRoom =
        ApiRoom(id: 'bedroom', houseId: 'house-001', name: 'Renamed bedroom');
    expect(FloorPlanBindings.objectNameFor(apiRoom), 'bedroom1');
    expect(
        FloorPlanBindings.objectNameFor(const ApiRoom(
            id: 'bedroom', houseId: 'another-house', name: 'Bedroom')),
        isNull);
    expect(
        FloorPlanBindings.objectNameFor(const ApiRoom(
            id: 'bedroom-2', houseId: 'house-001', name: 'Bedroom')),
        isNull);
  });

  test('all 14 devices get markers when API rooms omit GLB object names', () {
    const ids = ['living-room', 'kitchen', 'bedroom', 'bathroom1'];
    final rooms = [
      for (final id in ids) ApiRoom(id: id, houseId: 'house-001', name: id),
    ];
    final model = three.Group();
    for (var i = 0; i < rooms.length; i++) {
      model.add(floor(4, 4, i * 5.0, 0)
        ..name = FloorPlanBindings.objectNameFor(rooms[i])!);
    }
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    layer.sync(
      devices: [
        for (var i = 0; i < 12; i++)
          device(id: 'device-$i', roomId: ids[i ~/ 3]),
        sensor(
            id: 'device-013', type: 'smoke_detector', state: {'smoke': false}),
        sensor(
            id: 'device-014',
            type: 'temperature_sensor',
            roomId: 'living-room',
            state: {'temperature': 35}),
      ],
      rooms: rooms,
      house: model,
    );
    expect(layer.markers.length, 14);
    expect(layer.markers['device-013']!.floor.name, 'bedroom1');
    expect(layer.markers['device-014']!.floor.name, 'livingRoom');
    expect(layer.markers['device-013']!.body.getObjectByName('smoke-indicator'),
        isNotNull);
    expect(
        layer.markers['device-014']!.body
            .getObjectByName('temperature-indicator'),
        isNotNull);
  });

  test(
      'sensor readings work without a power capability and handle missing/offline data',
      () {
    DeviceVisualState visual(String type, Map<String, Object?> state,
            {bool operational = true}) =>
        DeviceVisualState(
            sensor(type: type, state: state, operational: operational));
    expect(visual('smoke_detector', {'smoke': false}).statusLabel,
        'No smoke detected');
    expect(visual('smoke_detector', {'smoke': true}).statusLabel,
        'Smoke detected');
    expect(
        visual('temperature_sensor', {'temperature': 35}).statusLabel, '35°C');
    expect(visual('temperature_sensor', {'temperature': 21.5}).statusLabel,
        '21.5°C');
    expect(visual('temperature_sensor', {'temperature': 0}).statusLabel, '0°C');
    expect(
        visual('temperature_sensor', {'temperature': double.nan}).statusLabel,
        'No reading');
    expect(visual('smoke_detector', {}).statusLabel, 'No reading');
    expect(
        visual('temperature_sensor', {'temperature': 35}, operational: false)
            .statusLabel,
        'Offline');
    expect(visual('smoke_detector', {'smoke': false}).hasSensorReading, isTrue);
    expect(visual('temperature_sensor', {}).hasSensorReading, isFalse);
  });

  test('smoke sensor marker changes on detection and goes grey when offline',
      () {
    final model = house();
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    void sync(bool detected, {bool operational = true}) => layer.sync(
          devices: [
            sensor(
                type: 'smoke_detector',
                roomId: 'living-room',
                state: {'smoke': detected},
                operational: operational)
          ],
          rooms: [room],
          house: model,
        );
    sync(false);
    final marker = layer.markers['sensor']!;
    final indicator = marker.body.getObjectByName('smoke-indicator')!;
    final healthyColor = indicator.material!.color.clone();
    sync(true);
    expect(layer.markers['sensor'], same(marker));
    final alarmColor = indicator.material!.color.clone();
    expect(alarmColor.red, greaterThan(healthyColor.red));
    expect(alarmColor.green, lessThan(healthyColor.green));
    sync(true, operational: false);
    final offlineColor = indicator.material!.color;
    expect(offlineColor.red, lessThan(alarmColor.red));
    expect(marker.glow, isNull);
    expect(marker.floorGlow, isNull);
  });

  test('light intensity follows capability scale and respects off/offline', () {
    expect(DeviceVisualState(device(brightness: 4)).lightIntensity, 0.04);
    expect(DeviceVisualState(device(brightness: 90)).lightIntensity, 0.9);
    expect(DeviceVisualState(device(power: false)).lightIntensity, 0);
    expect(DeviceVisualState(device(operational: false)).lightIntensity, 0);
    expect(
        DeviceVisualState(
                device(brightness: 20, brightnessMin: 10, brightnessMax: 30))
            .lightIntensity,
        0.5);
    expect(DeviceVisualState(device(brightness: 1000)).lightIntensity, 1);
    expect(DeviceVisualState(device(brightness: -100)).lightIntensity, 0);
    expect(DeviceVisualState(device(brightness: double.nan)).lightIntensity, 1);
  });

  test('fan animation speeds increase with declared speed and stop with power',
      () {
    final low = DeviceVisualState(device(type: 'fan', speed: 1));
    final high = DeviceVisualState(device(type: 'fan', speed: 3));
    expect(high.fanRadiansPerSecond, greaterThan(low.fanRadiansPerSecond));
    expect(
        DeviceVisualState(device(type: 'fan', power: false))
            .fanRadiansPerSecond,
        0);
  });

  test('markers stay inside an irregular room under world transforms', () {
    final model = house(irregular: true)
      ..position.setValues(5, 0.5, -3)
      ..scale.setValues(1.5, 1, 1.5);
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    layer.sync(
        devices: [for (var i = 0; i < 8; i++) device(id: 'light-$i')],
        rooms: [room],
        house: model);
    expect(layer.markers.length, 8);
    final points = <String>{};
    for (final marker in layer.markers.values) {
      final point = marker.floorPosition;
      final x = (point.x - 5) / 1.5;
      final z = (point.z + 3) / 1.5;
      expect(x, inInclusiveRange(-2.0, 2.0));
      expect(z, inInclusiveRange(-2.0, 2.0));
      expect(x <= 0 || z >= 0, isTrue, reason: 'Avoid missing floor quadrant');
      expect(point.y, closeTo(0.5, 0.001));
      points.add('${point.x},${point.z}');
    }
    expect(points.length, 8);
  });

  test('state changes and added devices preserve existing marker positions',
      () {
    final model = house();
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    layer.sync(devices: [device(id: 'light-2')], rooms: [room], house: model);
    final original = layer.markers['light-2']!;
    final position = original.floorPosition.clone();
    layer.sync(
        devices: [device(id: 'light-2', brightness: 90), device(id: 'light-1')],
        rooms: [room],
        house: model);
    expect(layer.markers['light-2'], same(original));
    expect(original.floorPosition.distanceTo(position), 0);
    expect(original.device.state['brightness'], 90);
    expect(layer.markers['light-1']!.floorPosition.distanceTo(position),
        greaterThan(0.1));
  });

  test('glow fades with brightness, power, and an API rollback', () {
    final model = house();
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    void sync(ApiDevice value) =>
        layer.sync(devices: [value], rooms: [room], house: model);
    void settle() {
      for (var i = 0; i < 100; i++) {
        layer.animate(0.016);
      }
    }

    sync(device(power: false));
    final marker = layer.markers['light-1']!;
    expect(marker.glow!.visible, isFalse);
    sync(device(brightness: 25));
    settle();
    final dimOpacity = marker.glow!.material!.opacity;
    final dimSize = marker.glow!.scale.x;
    expect(dimOpacity, closeTo(0.85 * 0.25, 0.001));
    sync(device(brightness: 100));
    layer.animate(0.016);
    expect(marker.glow!.material!.opacity, greaterThan(dimOpacity));
    expect(marker.glow!.material!.opacity, lessThan(0.85));
    settle();
    expect(marker.glow!.scale.x, greaterThan(dimSize));
    // The same old record emitted by DeviceBloc on failed PATCH removes glow.
    sync(device(power: false));
    settle();
    expect(marker.glow!.visible, isFalse);
    expect(marker.floorGlow!.visible, isFalse);
    expect(marker.glow!.material!.opacity, 0);
  });

  test('fan coasts to a stop and remains still while off', () {
    final model = house();
    final layer = FloorPlanDeviceLayer();
    addTearDown(layer.dispose);
    layer.sync(devices: [device(type: 'fan')], rooms: [room], house: model);
    final marker = layer.markers['light-1']!;
    layer.animate(0.016);
    expect(marker.rotor.rotation.y, greaterThan(0));
    layer.sync(
        devices: [device(type: 'fan', power: false)],
        rooms: [room],
        house: model);
    for (var i = 0; i < 100; i++) {
      layer.animate(0.016);
    }
    final stopped = marker.rotor.rotation.y;
    layer.animate(0.016);
    expect(marker.rotor.rotation.y, stopped);
  });

  test('removed or unmapped devices leave no markers and clear GPU resources',
      () {
    final model = house();
    final layer = FloorPlanDeviceLayer();
    layer.sync(devices: [
      device(),
      device(id: 'unassigned', roomId: null),
      device(id: 'unknown', roomId: 'unknown')
    ], rooms: [
      room
    ], house: model);
    expect(layer.markers.keys, ['light-1']);
    final removed = layer.markers['light-1']!;
    layer.sync(devices: [], rooms: [room], house: model);
    expect(layer.markers, isEmpty);
    expect(layer.object.children, isEmpty);
    expect(removed.object.parent, isNull);
    // Shared halo texture must survive individual marker removal.
    layer.sync(devices: [device()], rooms: [room], house: model);
    expect(layer.markers['light-1']!.glow!.material!.map, isNotNull);
    layer.dispose();
    expect(layer.markers, isEmpty);
    expect(layer.object.parent, isNull);
    layer.dispose();
  });
}
