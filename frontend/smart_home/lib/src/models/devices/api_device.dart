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

/// The complete immutable device record, using the backend's capability scales.
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

  /// A temporary local state update; the API response later replaces this record.
  ApiDevice withState(Map<String, Object?> updates) => ApiDevice(
        id: id,
        name: name,
        type: type,
        houseId: houseId,
        roomId: roomId,
        manufacturer: manufacturer,
        model: model,
        manufacturedYear: manufacturedYear,
        installedYear: installedYear,
        installer: installer,
        capabilities: capabilities,
        state: {...state, ...updates},
        status: status,
      );
}
