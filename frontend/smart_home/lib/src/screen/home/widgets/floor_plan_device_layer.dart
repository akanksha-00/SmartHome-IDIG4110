import 'dart:math' as math;
import 'dart:typed_data';

import 'package:smart_home/src/config/floor_plan_bindings.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/rooms/api_room.dart';
import 'package:three_js/three_js.dart' as three;

/// A presentation of API state using the capability's own value range.
class DeviceVisualState {
  DeviceVisualState(ApiDevice device)
      : type = device.type.toLowerCase(),
        isOperational = device.status['operational'] != false,
        isOn = device.state['power'] == true &&
            device.status['operational'] != false,
        smokeDetected = device.state['smoke'] is bool
            ? device.state['smoke'] as bool
            : null,
        temperature = _reading(device.state['temperature']),
        speed = device.state['speed'],
        brightness = _level(device, 'brightness', 0, 100, 1),
        fanSpeed = _level(device, 'speed', 0, 3, 0.5);

  final String type;
  final bool isOperational;
  final bool isOn;
  final bool? smokeDetected;
  final num? temperature;
  final Object? speed;
  final double brightness;
  final double fanSpeed;

  bool get isSensor => type == 'smoke_detector' || type == 'temperature_sensor';
  bool get hasSensorReading =>
      type == 'smoke_detector' ? smokeDetected != null : temperature != null;

  String get statusLabel {
    if (!isOperational) return 'Offline';
    if (type == 'smoke_detector') {
      return switch (smokeDetected) {
        true => 'Smoke detected',
        false => 'No smoke detected',
        null => 'No reading',
      };
    }
    if (type == 'temperature_sensor') {
      final value = temperature;
      if (value == null) return 'No reading';
      return '${value.toStringAsFixed(value == value.round() ? 0 : 1)}°C';
    }
    if (!isOn) return 'Off';
    return switch (type) {
      'light' => '${(brightness * 100).round()}% brightness',
      'fan' => 'On · Speed ${speed ?? '—'}',
      _ => 'On',
    };
  }

  double get lightIntensity => isOn ? brightness : 0;
  double get fanRadiansPerSecond =>
      isOn ? 2 * math.pi * (0.5 + 2 * fanSpeed) : 0;

  static num? _reading(Object? value) =>
      value is num && value.isFinite ? value : null;

  static double _level(ApiDevice device, String name, num defaultMin,
      num defaultMax, double fallback) {
    final value = device.state[name];
    if (value is! num || !value.isFinite) return fallback;
    final capability = device.capabilities[name];
    final min = capability?.min ?? defaultMin;
    final max = capability?.max ?? defaultMax;
    if (!min.isFinite || !max.isFinite || max <= min) return fallback;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }
}

/// Runtime markers, independent of the renderer and the Blender asset.
/// Positions are provisional room placements until the API stores coordinates.
class FloorPlanDeviceLayer {
  final object = three.Group()..name = 'device-markers';
  final Map<String, FloorPlanDeviceMarker> markers = {};
  final Map<String, _RoomPlacement> _placements = {};
  late final three.DataTexture _glowTexture = _createGlowTexture();
  bool _textureCreated = false;
  bool _disposed = false;

  void sync({
    required List<ApiDevice> devices,
    required List<ApiRoom> rooms,
    required three.Object3D house,
  }) {
    if (_disposed) return;
    house.updateWorldMatrix(true, true);
    final mappedRooms = {
      for (final room in rooms)
        if (FloorPlanBindings.objectNameFor(room) != null) room.id: room,
    };
    final validIds = {
      for (final device in devices)
        if (mappedRooms.containsKey(device.roomId)) device.id,
    };
    for (final id in markers.keys.toList()) {
      if (!validIds.contains(id)) _remove(id);
    }
    for (final id in _placements.keys.toList()) {
      if (!mappedRooms.containsKey(id)) _placements.remove(id);
    }

    final houseBounds = three.BoundingBox().setFromObject(house);
    if (houseBounds.isEmpty()) return;
    final extent = houseBounds.getSize(three.Vector3.zero());
    final markerSize = (math.max(extent.x, extent.z) / 10).clamp(0.35, 2.0);
    final markerHeight = math.max(extent.y + 0.2 * markerSize, markerSize);

    // ID order only determines initial placement; state changes and additions
    // preserve the positions of devices already present in a room.
    final sorted = [...devices]..sort((a, b) => a.id.compareTo(b.id));
    for (final device in sorted) {
      final room = mappedRooms[device.roomId];
      if (room == null) continue;
      final floor =
          house.getObjectByName(FloorPlanBindings.objectNameFor(room)!);
      if (floor == null) {
        _remove(device.id);
        continue;
      }
      var placement = _placements[room.id];
      if (placement == null || placement.floor != floor) {
        placement = _RoomPlacement(floor);
        _placements[room.id] = placement;
      }
      var marker = markers[device.id];
      if (marker != null &&
          (marker.device.roomId != device.roomId ||
              marker.device.type != device.type ||
              marker.floor != floor)) {
        _remove(device.id);
        marker = null;
      }
      if (marker == null) {
        final occupied = markers.values
            .where((other) => other.device.roomId == room.id)
            .map((other) => other.floorPosition)
            .toList();
        final position = placement.nextPosition(occupied);
        if (position == null) continue;
        _textureCreated = true;
        marker = FloorPlanDeviceMarker(
          device: device,
          floor: floor,
          floorPosition: position,
          size: markerSize,
          height: markerHeight,
          glowTexture: _glowTexture,
        );
        markers[device.id] = marker;
        object.add(marker.object);
      }
      marker.updateDevice(device);
    }
    object.updateMatrixWorld(true);
  }

  void animate(double dt) {
    if (_disposed || !dt.isFinite || dt <= 0) return;
    // Returning to a hidden browser tab should not jump fan rotation/fades.
    final elapsed = math.min(dt, 0.05);
    for (final marker in markers.values) {
      marker.animate(elapsed);
    }
  }

  ApiDevice? pick(three.Raycaster raycaster) {
    object.updateMatrixWorld(true);
    ApiDevice? closest;
    var distance = double.infinity;
    for (final marker in markers.values) {
      // Ignore the large transparent glow when picking a device.
      final hits = raycaster.intersectObject(marker.body, true);
      if (hits.isNotEmpty && hits.first.distance < distance) {
        distance = hits.first.distance;
        closest = marker.device;
      }
    }
    return closest;
  }

  void _remove(String id) => markers.remove(id)?.dispose();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    object.removeFromParent();
    for (final id in markers.keys.toList()) {
      _remove(id);
    }
    _placements.clear();
    if (_textureCreated) _glowTexture.dispose();
  }
}

class _RoomPlacement {
  _RoomPlacement(this.floor) {
    final bounds = three.BoundingBox().setFromObject(floor);
    if (bounds.isEmpty()) return;
    final width = bounds.max.x - bounds.min.x;
    final depth = bounds.max.z - bounds.min.z;
    if (width <= 0 || depth <= 0) return;
    final raycaster = three.Raycaster();
    final direction = three.Vector3(0, -1, 0);
    final origin = three.Vector3.zero();
    // Test the actual floor triangles, avoiding holes and adjacent rooms in
    // irregular footprints rather than trusting a rectangular bounding box.
    for (var z = 0; z < 9; z++) {
      for (var x = 0; x < 9; x++) {
        origin.setValues(
          bounds.min.x + width * (0.16 + 0.68 * x / 8),
          bounds.max.y + 1,
          bounds.min.z + depth * (0.16 + 0.68 * z / 8),
        );
        raycaster.set(origin, direction);
        final hits = raycaster.intersectObject(floor, true);
        if (hits.isNotEmpty && hits.first.point != null) {
          candidates.add(hits.first.point!.clone());
        }
      }
    }
    bounds.getCenter(center);
  }

  final three.Object3D floor;
  final List<three.Vector3> candidates = [];
  final center = three.Vector3.zero();

  three.Vector3? nextPosition(List<three.Vector3> occupied) {
    three.Vector3? best;
    var score = -double.infinity;
    for (final candidate in candidates) {
      final candidateScore = occupied.isEmpty
          ? -candidate.distanceToSquared(center)
          : occupied.map(candidate.distanceToSquared).reduce(math.min);
      if (candidateScore > score) {
        score = candidateScore;
        best = candidate;
      }
    }
    // Do not stack additional markers at an already occupied anchor.
    return occupied.isNotEmpty && score < 0.0001 ? null : best?.clone();
  }
}

class FloorPlanDeviceMarker {
  FloorPlanDeviceMarker({
    required this.device,
    required this.floor,
    required this.floorPosition,
    required double size,
    required double height,
    required three.DataTexture glowTexture,
  }) {
    object.name = 'device-${device.id}';
    object.position.setFrom(floorPosition);
    object.position.y += height;
    object.scale.setValues(size, size, size);
    object.add(body);
    final stem = _mesh(three.BoxGeometry(0.1, 0.12, 0.1), _socketMaterial);
    body.add(stem);
    switch (device.type.toLowerCase()) {
      case 'light':
        final bulb = _mesh(three.SphereGeometry(0.18, 16, 12), _activeMaterial);
        bulb.position.y = 0.2;
        body.add(bulb);
        glow = three.Sprite(three.SpriteMaterial.fromMap({
          'map': glowTexture,
          'color': 0xFFB547,
          'sizeAttenuation': true,
          'depthWrite': false,
          'toneMapped': false,
          'blending': three.AdditiveBlending,
        }));
        glow!.position.y = 0.2;
        glow!.material!.color =
            three.Color.fromHex32(0xFFB547).convertSRGBToLinear();
        object.add(glow!);
        floorGlow = _mesh(
          three.PlaneGeometry(1, 1),
          three.MeshBasicMaterial.fromMap({
            'map': glowTexture,
            'color': 0xFFB547,
            'transparent': true,
            'depthWrite': false,
            'toneMapped': false,
            'side': three.DoubleSide,
          }),
        );
        floorGlow!.rotation.x = -math.pi / 2;
        floorGlow!.material!.color =
            three.Color.fromHex32(0xFFB547).convertSRGBToLinear();
        floorGlow!.position.y = (-height + 0.035 * size) / size;
        object.add(floorGlow!);
      case 'fan':
        // Hang the rotor below its mounting stem.
        body.rotation.z = math.pi;
        body.add(rotor);
        final hub = _mesh(three.SphereGeometry(0.09, 12, 8), _activeMaterial);
        hub.position.y = 0.12;
        rotor.add(hub);
        for (var i = 0; i < 3; i++) {
          final arm = three.Group();
          arm.rotation.y = i * 2 * math.pi / 3;
          final blade =
              _mesh(three.BoxGeometry(0.3, 0.06, 0.13), _activeMaterial);
          blade.position.setValues(0.18, 0.12, 0);
          arm.add(blade);
          rotor.add(arm);
        }
      case 'smoke_detector':
        final housing = _mesh(
            three.CylinderGeometry(0.22, 0.22, 0.09, 20), _socketMaterial);
        housing.position.y = 0.14;
        body.add(housing);
        final cover = _mesh(three.CylinderGeometry(0.18, 0.18, 0.025, 20),
            _sensorHousingMaterial);
        cover.position.y = 0.18;
        body.add(cover);
        for (final x in [-0.07, 0.0, 0.07]) {
          final vent =
              _mesh(three.BoxGeometry(0.025, 0.01, 0.13), _socketMaterial);
          vent.position.setValues(x, 0.197, -0.04);
          body.add(vent);
        }
        final indicator =
            _mesh(three.SphereGeometry(0.035, 12, 8), _activeMaterial)
              ..name = 'smoke-indicator';
        indicator.position.setValues(0.1, 0.2, 0.08);
        body.add(indicator);
      case 'temperature_sensor':
        final housing =
            _mesh(three.BoxGeometry(0.16, 0.42, 0.1), _sensorHousingMaterial);
        housing.position.y = 0.23;
        body.add(housing);
        final tube = _mesh(
            three.CylinderGeometry(0.026, 0.026, 0.25, 12), _activeMaterial);
        tube.position.setValues(0, 0.26, 0.075);
        body.add(tube);
        final bulb = _mesh(three.SphereGeometry(0.06, 12, 8), _activeMaterial)
          ..name = 'temperature-indicator';
        bulb.position.setValues(0, 0.1, 0.075);
        body.add(bulb);
      default:
        // Turn the pins toward the floor while keeping the plug body centred.
        body.rotation.z = math.pi;
        body.position.y = 0.28;
        final plug =
            _mesh(three.BoxGeometry(0.25, 0.27, 0.18), _activeMaterial);
        plug.position.y = 0.14;
        body.add(plug);
        for (final x in [-0.06, 0.06]) {
          final pin =
              _mesh(three.BoxGeometry(0.04, 0.12, 0.05), _socketMaterial);
          pin.position.setValues(x, 0.32, 0);
          body.add(pin);
        }
    }
    _visual = DeviceVisualState(device);
    _intensity = _visual.lightIntensity;
    _fanSpeed = _visual.fanRadiansPerSecond;
    _paint();
  }

  ApiDevice device;
  final three.Object3D floor;
  final three.Vector3 floorPosition;
  final object = three.Group();
  final body = three.Group();
  final rotor = three.Group();
  three.Sprite? glow;
  three.Mesh? floorGlow;
  late DeviceVisualState _visual;
  double _intensity = 0;
  double _fanSpeed = 0;
  final _offColor = three.Color.fromHex32(0x64748B).convertSRGBToLinear();
  final _alarmColor = three.Color.fromHex32(0xF87171).convertSRGBToLinear();
  late final _onColor = three.Color.fromHex32(
          device.type.toLowerCase() == 'light' ? 0xFFD166 : 0x5EEAD4)
      .convertSRGBToLinear();

  final _activeMaterial = three.MeshBasicMaterial.fromMap({
    'color': 0x64748B,
    'toneMapped': false,
  });
  final _socketMaterial = three.MeshBasicMaterial.fromMap({
    'color': 0x334155,
    'toneMapped': false,
  });
  late final _sensorHousingMaterial = three.MeshBasicMaterial.fromMap({
    'color': 0xCBD5E1,
    'toneMapped': false,
  });

  void updateDevice(ApiDevice next) {
    device = next;
    _visual = DeviceVisualState(next);
    _paint();
  }

  void animate(double dt) {
    final blend = 1 - math.exp(-10 * dt);
    _intensity += (_visual.lightIntensity - _intensity) * blend;
    _fanSpeed += (_visual.fanRadiansPerSecond - _fanSpeed) * blend;
    if ((_intensity - _visual.lightIntensity).abs() < 0.001) {
      _intensity = _visual.lightIntensity;
    }
    if ((_fanSpeed - _visual.fanRadiansPerSecond).abs() < 0.001) {
      _fanSpeed = _visual.fanRadiansPerSecond;
    }
    rotor.rotation.y = (rotor.rotation.y + dt * _fanSpeed) % (2 * math.pi);
    _paint();
  }

  void _paint() {
    final type = device.type.toLowerCase();
    if (_visual.isSensor) {
      final color = !_visual.isOperational || !_visual.hasSensorReading
          ? _offColor
          : type == 'smoke_detector' && _visual.smokeDetected == true
              ? _alarmColor
              : _onColor;
      _activeMaterial.color.setFrom(color);
    } else {
      final strength =
          type == 'light' ? _intensity : (_visual.isOn ? 1.0 : 0.0);
      _activeMaterial.color.lerpColors(_offColor, _onColor, strength);
    }
    final visible = _intensity > 0.001;
    if (glow != null) {
      glow!.visible = visible;
      glow!.material!.opacity = 0.85 * _intensity;
      final diameter = 0.55 + 0.9 * _intensity;
      glow!.scale.setValues(diameter, diameter, 1);
    }
    if (floorGlow != null) {
      floorGlow!.visible = visible;
      floorGlow!.material!.opacity = 0.5 * _intensity;
      // Limit the wash so it remains a local effect around each marker.
      final diameter = 1 + 0.8 * _intensity;
      floorGlow!.scale.setValues(diameter, diameter, 1);
    }
  }

  void dispose() {
    object.removeFromParent();
    final materials = <three.Material>{};
    object.traverse((node) {
      // Sprite geometry is shared by the library across every Sprite.
      if (node is! three.Sprite) node.geometry?.dispose();
      final material = node.material;
      if (material != null) materials.add(material);
    });
    for (final material in materials) {
      // The glow texture belongs to the layer, not to individual markers.
      material.map = null;
      material.dispose();
    }
    object.clear();
  }

  static three.Mesh _mesh(
          three.BufferGeometry geometry, three.Material material) =>
      three.Mesh(geometry, material);
}

three.DataTexture _createGlowTexture() {
  const size = 64;
  final bytes = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = (x + 0.5 - size / 2) / (size / 2);
      final dy = (y + 0.5 - size / 2) / (size / 2);
      final radius = math.sqrt(dx * dx + dy * dy);
      final alpha = math.pow((1 - radius).clamp(0.0, 1.0), 2.5);
      final offset = (y * size + x) * 4;
      bytes[offset] = 255;
      bytes[offset + 1] = 255;
      bytes[offset + 2] = 255;
      bytes[offset + 3] = (alpha * 255).round();
    }
  }
  return three.DataTexture(bytes, size, size)
    ..magFilter = three.LinearFilter
    ..minFilter = three.LinearFilter
    ..needsUpdate = true;
}
