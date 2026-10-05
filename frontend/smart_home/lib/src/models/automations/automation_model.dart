enum AutomationTriggerType { schedule, sunset, temperature }

enum AutomationRepeat { daily, weekdays, weekends }

enum AutomationActionType { turnOn, turnOff, brightness, fanSpeed }

enum AutomationRunStatus { completed, failed }

class AutomationTrigger {
  const AutomationTrigger({
    required this.type,
    this.minutesOfDay = 420,
    this.repeat = AutomationRepeat.daily,
    this.temperatureC = 26,
  }) : assert(minutesOfDay >= 0 && minutesOfDay < 1440);

  final AutomationTriggerType type;
  final int minutesOfDay;
  final AutomationRepeat repeat;
  final double temperatureC;

  String get description {
    final repeatLabel = switch (repeat) {
      AutomationRepeat.daily => 'Daily',
      AutomationRepeat.weekdays => 'Weekdays',
      AutomationRepeat.weekends => 'Weekends',
    };
    return switch (type) {
      AutomationTriggerType.schedule =>
        '${(minutesOfDay ~/ 60).toString().padLeft(2, '0')}:'
            '${(minutesOfDay % 60).toString().padLeft(2, '0')} · $repeatLabel',
      AutomationTriggerType.sunset => 'At sunset · $repeatLabel',
      AutomationTriggerType.temperature =>
        'Temperature rises above ${temperatureC.toStringAsFixed(temperatureC % 1 == 0 ? 0 : 1)}°C',
    };
  }
}

class AutomationAction {
  AutomationAction({
    required this.type,
    required List<String> deviceIds,
    this.level = 80,
  }) : deviceIds = List.unmodifiable(deviceIds) {
    if (deviceIds.isEmpty || deviceIds.toSet().length != deviceIds.length) {
      throw ArgumentError('An action needs distinct target devices.');
    }
    if ((type == AutomationActionType.brightness &&
            (level < 0 || level > 100)) ||
        (type == AutomationActionType.fanSpeed && (level < 1 || level > 3))) {
      throw ArgumentError('Invalid automation action level.');
    }
  }

  final AutomationActionType type;
  final List<String> deviceIds;
  final int level;

  String describe(Map<String, String> deviceTitles) {
    final targets =
        deviceIds.map((id) => deviceTitles[id] ?? 'Unknown device').join(' + ');
    final command = switch (type) {
      AutomationActionType.turnOn => 'On',
      AutomationActionType.turnOff => 'Off',
      AutomationActionType.brightness => '$level%',
      AutomationActionType.fanSpeed => 'On, speed $level',
    };
    return '$targets → $command';
  }
}

class AutomationModel {
  const AutomationModel({
    required this.id,
    required this.title,
    required this.floorId,
    required this.roomId,
    required this.trigger,
    required this.action,
    this.isEnabled = true,
  });

  final String id;
  final String title;
  final String floorId;
  final String roomId;
  final AutomationTrigger trigger;
  final AutomationAction action;
  final bool isEnabled;

  AutomationModel withEnabled(bool value) => AutomationModel(
        id: id,
        title: title,
        floorId: floorId,
        roomId: roomId,
        trigger: trigger,
        action: action,
        isEnabled: value,
      );
}

// These snapshots remain meaningful after a routine is renamed or removed.
class AutomationRun {
  const AutomationRun({
    required this.id,
    required this.automationId,
    required this.title,
    required this.floorId,
    required this.roomId,
    required this.triggerType,
    required this.timeLabel,
    required this.status,
    this.detail,
  });

  final String id;
  final String automationId;
  final String title;
  final String floorId;
  final String roomId;
  final AutomationTriggerType triggerType;
  final String timeLabel;
  final AutomationRunStatus status;
  final String? detail;
}
