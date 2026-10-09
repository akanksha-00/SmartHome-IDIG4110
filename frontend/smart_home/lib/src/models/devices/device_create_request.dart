import 'package:smart_home/src/models/devices/api_device.dart';

/// Data accepted by the device creation endpoint.
class DeviceCreateRequest {
  DeviceCreateRequest({
    required this.id,
    required this.name,
    required this.type,
    required this.roomId,
    Map<String, DeviceCapability> capabilities = const {},
    Map<String, Object?> state = const {},
  })  : capabilities = Map.unmodifiable(capabilities),
        state = Map.unmodifiable(state);

  final String id;
  final String name;
  final String type;
  final String roomId;
  final Map<String, DeviceCapability> capabilities;
  final Map<String, Object?> state;
}
