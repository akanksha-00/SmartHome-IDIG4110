enum AlarmMode { disarmed, home, away }

enum SafetyDeviceType {
  smoke,
  heat,
  carbonMonoxide,
  waterLeak,
  door,
  window,
  motion
}

enum SafetyDeviceState {
  normal,
  warning,
  alarm,
  dry,
  wet,
  closed,
  open,
  clear,
  detected,
  unknown
}

class SafetyDevice {
  const SafetyDevice({
    required this.id,
    required this.title,
    required this.type,
    required this.floorId,
    required this.roomId,
    required this.location,
    this.state = SafetyDeviceState.unknown,
    this.isOnline = false,
    this.batteryPercent,
    this.temperatureC,
    this.isLocked,
  }) : assert(batteryPercent == null ||
            (batteryPercent >= 0 && batteryPercent <= 100));

  final String id;
  final String title;
  final SafetyDeviceType type;
  final String floorId;
  final String roomId;
  final String location;
  final SafetyDeviceState state;
  final bool isOnline;
  final int? batteryPercent;
  final double? temperatureC;
  final bool? isLocked;

  bool get isSafetySensor => switch (type) {
        SafetyDeviceType.smoke ||
        SafetyDeviceType.heat ||
        SafetyDeviceType.carbonMonoxide ||
        SafetyDeviceType.waterLeak =>
          true,
        _ => false,
      };
  bool get isContact =>
      type == SafetyDeviceType.door || type == SafetyDeviceType.window;
  bool get hasLowBattery => batteryPercent != null && batteryPercent! <= 20;
  bool get isAlert =>
      isOnline &&
      switch (state) {
        SafetyDeviceState.warning ||
        SafetyDeviceState.alarm ||
        SafetyDeviceState.wet ||
        SafetyDeviceState.open ||
        SafetyDeviceState.detected =>
          true,
        _ => false,
      };
  bool get needsAttention =>
      !isOnline ||
      state == SafetyDeviceState.unknown ||
      isAlert ||
      hasLowBattery;

  String get stateLabel {
    if (!isOnline) return 'Unknown';
    return switch (state) {
      SafetyDeviceState.normal => 'Normal',
      SafetyDeviceState.warning => 'Warning',
      SafetyDeviceState.alarm => 'Alarm',
      SafetyDeviceState.dry => 'Dry',
      SafetyDeviceState.wet => 'Leak detected',
      SafetyDeviceState.closed => 'Closed',
      SafetyDeviceState.open => 'Open',
      SafetyDeviceState.clear => 'Clear',
      SafetyDeviceState.detected => 'Motion',
      SafetyDeviceState.unknown => 'Unknown',
    };
  }

  String get attentionMessage {
    if (!isOnline) return '$title is offline';
    if (state == SafetyDeviceState.unknown) {
      return '$title has no current reading';
    }
    if (isAlert) return '$title: ${stateLabel.toLowerCase()}';
    return '$title has a low battery';
  }

  SafetyDevice withDetails(
          {required String title,
          required String roomId,
          required String location}) =>
      SafetyDevice(
        id: id,
        title: title,
        type: type,
        floorId: floorId,
        roomId: roomId,
        location: location,
        state: state,
        isOnline: isOnline,
        batteryPercent: batteryPercent,
        temperatureC: temperatureC,
        isLocked: isLocked,
      );
}

class SafetyEvent {
  const SafetyEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.type,
    this.deviceId,
    this.floorId,
    this.roomId,
  });

  final String id;
  final String title;
  final String description;
  final String timeLabel;
  final SafetyDeviceType type;
  final String? deviceId;
  final String? floorId;
  final String? roomId;
}
