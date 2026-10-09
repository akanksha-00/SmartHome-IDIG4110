class SensorReading {
  const SensorReading({
    required this.id,
    required this.deviceId,
    required this.roomId,
    required this.type,
    required this.value,
    required this.isOnline,
    this.unit,
    this.recordedAt,
  });

  final String id;
  final String deviceId;
  final String roomId;
  final String type;

  /// A number, boolean, text, or null when no reading is available.
  final Object? value;
  final String? unit;
  final bool isOnline;
  final DateTime? recordedAt;
}
