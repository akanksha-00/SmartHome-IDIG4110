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

  /// A matching save response should not redraw unchanged device visuals.
  bool hasSameValuesAs(ApiDevice other) =>
      id == other.id &&
      name == other.name &&
      type == other.type &&
      houseId == other.houseId &&
      roomId == other.roomId &&
      manufacturer == other.manufacturer &&
      model == other.model &&
      manufacturedYear == other.manufacturedYear &&
      installedYear == other.installedYear &&
      installer == other.installer &&
      _sameValues(state, other.state) &&
      _sameValues(status, other.status) &&
      capabilities.length == other.capabilities.length &&
      capabilities.entries.every((entry) {
        final next = other.capabilities[entry.key];
        return next != null &&
            entry.value.type == next.type &&
            entry.value.min == next.min &&
            entry.value.max == next.max;
      });

  static bool _sameValues(Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length &&
      a.entries.every(
          (entry) => b.containsKey(entry.key) && b[entry.key] == entry.value);

  /// Merges capability values, or replaces the state for an exact rollback.
  ApiDevice withState(Map<String, Object?> updates, {bool replace = false}) =>
      ApiDevice(
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
        state: replace ? updates : {...state, ...updates},
        status: status,
      );
}
