/// A capability declared by the backend, including its optional numeric limits.
class DeviceCapability {
  const DeviceCapability({required this.type, this.min, this.max});

  final String type;
  final num? min;
  final num? max;

  Map<String, Object?> toJson() => {
        'type': type,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };
}

/// The complete API device record. Existing UI models are left unchanged.
///
/// Capability names, device types, and state scales are defined by the backend;
/// retain them until a UI adapter is added during screen integration.
class ApiDevice {
  ApiDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.houseId,
    this.roomId,
    this.manufacturer,
    this.model,
    this.manufacturedYear,
    this.installedYear,
    this.installer,
    Map<String, DeviceCapability> capabilities = const {},
    Map<String, Object?> state = const {},
    Map<String, Object?> status = const {},
  })  : capabilities = Map.unmodifiable(capabilities),
        state = Map.unmodifiable(state),
        status = Map.unmodifiable(status);

  final String id;
  final String name;
  final String type;
  final String houseId;
  final String? roomId;
  final String? manufacturer;
  final String? model;
  final int? manufacturedYear;
  final int? installedYear;
  final String? installer;
  final Map<String, DeviceCapability> capabilities;
  final Map<String, Object?> state;
  final Map<String, Object?> status;
}
