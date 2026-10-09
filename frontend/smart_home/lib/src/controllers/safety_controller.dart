import 'package:flutter/foundation.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';

// Local UI state. A backend will supply readings, command results and history.
class SafetyController extends ChangeNotifier {
  SafetyController(
      {required List<SafetyDevice> devices, required List<SafetyEvent> events})
      : _devices = List.of(devices),
        _events = List.of(events);

  final List<SafetyDevice> _devices;
  final List<SafetyEvent> _events;
  AlarmMode _mode = AlarmMode.disarmed;
  int _eventSequence = 0;

  List<SafetyDevice> get devices => List.unmodifiable(_devices);
  List<SafetyEvent> get events => List.unmodifiable(_events);
  AlarmMode get mode => _mode;
  List<SafetyDevice> get attentionDevices =>
      _devices.where((device) => device.needsAttention).toList();

  List<String> armingIssues(AlarmMode requested) {
    if (requested == AlarmMode.disarmed) return [];
    final contacts = _devices.where((device) => device.isContact).toList();
    final issues = <String>[];
    if (contacts.isEmpty) {
      issues.add('No door or window sensors are available.');
    }
    for (final device in _devices) {
      if (!device.isContact &&
          !(requested == AlarmMode.away &&
              device.type == SafetyDeviceType.motion)) {
        continue;
      }
      if (!device.isOnline || device.state == SafetyDeviceState.unknown) {
        issues.add('${device.title} has no current reading.');
      } else if (device.isContact && device.state != SafetyDeviceState.closed) {
        issues.add('${device.title} must be closed.');
      }
    }
    return issues;
  }

  bool setMode(AlarmMode requested) {
    if (armingIssues(requested).isNotEmpty) return false;
    if (_mode == requested) return true;
    _mode = requested;
    _record(
      title: requested == AlarmMode.disarmed
          ? 'Intrusion disarmed'
          : 'Intrusion armed ${requested.name}',
      description: requested == AlarmMode.home
          ? 'Door and window monitoring enabled; indoor motion excluded.'
          : requested == AlarmMode.away
              ? 'Door, window and motion monitoring enabled.'
              : 'Intrusion monitoring disabled. Safety sensors remain enabled.',
    );
    notifyListeners();
    return true;
  }

  void saveDevice(SafetyDevice device) {
    final index = _devices.indexWhere((item) => item.id == device.id);
    if (index < 0) {
      _devices.add(device);
    } else {
      _devices[index] = device;
    }
    _record(
      title: '${device.title} ${index < 0 ? 'added' : 'updated'}',
      description: index < 0
          ? 'Device registered. Awaiting a connection and sensor readings.'
          : 'Device details updated.',
      device: device,
    );
    _checkCoverage();
    notifyListeners();
  }

  void removeDevice(String id) {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) return;
    final device = _devices.removeAt(index);
    _record(
        title: '${device.title} removed',
        description: 'Device removed; earlier events retained.',
        device: device);
    _checkCoverage();
    notifyListeners();
  }

  void _checkCoverage() {
    if (_mode != AlarmMode.disarmed && armingIssues(_mode).isNotEmpty) {
      _mode = AlarmMode.disarmed;
      _record(
          title: 'Intrusion disarmed',
          description:
              'Sensor coverage changed. Review devices before arming again.');
    }
  }

  void _record(
          {required String title,
          required String description,
          SafetyDevice? device}) =>
      _events.insert(
          0,
          SafetyEvent(
            id: 'local-${++_eventSequence}',
            title: title,
            description: description,
            timeLabel: 'Just now',
            type: device?.type ?? SafetyDeviceType.door,
            deviceId: device?.id,
            floorId: device?.floorId,
            roomId: device?.roomId,
          ));
}
