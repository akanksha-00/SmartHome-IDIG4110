import 'package:smart_home/src/models/devices/device_create_request.dart';

sealed class DeviceEvent {
  const DeviceEvent();
}

/// Startup requests reuse loaded data. An explicit refresh sets force to true.
final class DevicesRequested extends DeviceEvent {
  const DevicesRequested({this.force = false});
  final bool force;
}

final class DeviceStateUpdateRequested extends DeviceEvent {
  DeviceStateUpdateRequested(
      {required this.id, required Map<String, Object?> updates})
      : updates = Map.unmodifiable(updates);
  final String id;
  final Map<String, Object?> updates;
}

final class DeviceAddRequested extends DeviceEvent {
  const DeviceAddRequested(this.device);
  final DeviceCreateRequest device;
}
