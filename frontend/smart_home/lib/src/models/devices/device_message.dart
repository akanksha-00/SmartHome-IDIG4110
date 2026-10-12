/// The two message formats broadcast by the backend's house WebSocket.
/// No subscription, room metadata, or notification timestamps are on the wire.
class DeviceMessage {
  DeviceMessage({
    required this.deviceId,
    required Map<String, Object?> updates,
    this.event,
    this.value,
    this.alert = false,
    this.notificationMessage,
  }) : updates = Map.unmodifiable(updates);

  final String deviceId;
  final Map<String, Object?> updates;
  final String? event;
  final Object? value;
  final bool alert;
  final String? notificationMessage;

  static DeviceMessage? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type != 'device_state' && type != 'device_event') return null;
    final id = json['device_id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('WebSocket message has no device_id');
    }
    if (type == 'device_state') {
      final state = json['state'];
      if (state is! Map<String, dynamic>) {
        throw const FormatException('device_state requires a state object');
      }
      return DeviceMessage(deviceId: id, updates: state);
    }
    final event = json['event'];
    final alert = json['alert'];
    final message = json['notification_message'];
    if (event is! String ||
        event.isEmpty ||
        !json.containsKey('value') ||
        alert is! bool ||
        (message != null && message is! String)) {
      throw const FormatException('Invalid device_event message');
    }
    return DeviceMessage(
      deviceId: id,
      updates: {event: json['value']},
      event: event,
      value: json['value'],
      alert: alert,
      notificationMessage: message as String?,
    );
  }
}
