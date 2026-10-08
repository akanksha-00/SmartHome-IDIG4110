/// Session-only dashboard history. Sequence/read/active are local UI state,
/// never fields added to the backend schema or sent in requests.
class DeviceAlert {
  const DeviceAlert({
    required this.sequence,
    required this.deviceId,
    required this.event,
    required this.value,
    required this.message,
    this.isRead = false,
    this.isActive = true,
  });

  final int sequence;
  final String deviceId;
  final String event;
  final Object? value;
  final String message;
  final bool isRead;
  final bool isActive;

  DeviceAlert copyWith({bool? isRead, bool? isActive}) => DeviceAlert(
        sequence: sequence,
        deviceId: deviceId,
        event: event,
        value: value,
        message: message,
        isRead: isRead ?? this.isRead,
        isActive: isActive ?? this.isActive,
      );
}
