import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/controllers/safety_controller.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';

SafetyDevice contact(
        {bool online = true,
        SafetyDeviceState state = SafetyDeviceState.closed}) =>
    SafetyDevice(
      id: 'door',
      title: 'Door',
      type: SafetyDeviceType.door,
      floorId: 'floor1',
      roomId: 'living',
      location: 'Entrance',
      isOnline: online,
      state: state,
    );

void main() {
  test('open contacts block arming without fabricating an armed event', () {
    final controller = SafetyController(
        devices: sampleSafetyDevices, events: sampleSafetyEvents);
    addTearDown(controller.dispose);
    expect(controller.setMode(AlarmMode.away), isFalse);
    expect(controller.mode, AlarmMode.disarmed);
    expect(controller.events.length, sampleSafetyEvents.length);
    expect(controller.armingIssues(AlarmMode.home).single,
        contains('Kitchen window'));
  });

  test('offline and unknown contacts cannot appear ready to arm', () {
    for (final device in [
      contact(online: false),
      contact(state: SafetyDeviceState.unknown)
    ]) {
      final controller = SafetyController(devices: [device], events: []);
      addTearDown(controller.dispose);
      expect(controller.setMode(AlarmMode.home), isFalse);
      expect(device.stateLabel, 'Unknown');
      expect(device.needsAttention, isTrue);
    }
    final noSensors = SafetyController(devices: [], events: []);
    addTearDown(noSensors.dispose);
    expect(noSensors.setMode(AlarmMode.away), isFalse);
  });

  test('home excludes indoor motion; away needs its current readings', () {
    final controller = SafetyController(devices: [
      contact(),
      const SafetyDevice(
        id: 'motion',
        title: 'Motion',
        type: SafetyDeviceType.motion,
        floorId: 'floor1',
        roomId: 'living',
        location: 'Hallway',
      )
    ], events: []);
    addTearDown(controller.dispose);
    expect(controller.setMode(AlarmMode.home), isTrue);
    expect(controller.mode, AlarmMode.home);
    expect(controller.setMode(AlarmMode.away), isFalse);
    expect(controller.mode, AlarmMode.home);
    expect(controller.setMode(AlarmMode.disarmed), isTrue);
    expect(controller.events.length, 2);
  });

  test('disarming does not disable safety sensors', () {
    final controller = SafetyController(
        devices: [contact(), sampleSafetyDevices.first], events: []);
    addTearDown(controller.dispose);
    expect(controller.setMode(AlarmMode.away), isTrue);
    expect(controller.setMode(AlarmMode.disarmed), isTrue);
    final smoke =
        controller.devices.singleWhere((device) => device.isSafetySensor);
    expect(smoke.isOnline, isTrue);
    expect(smoke.stateLabel, 'Normal');
  });

  test(
      'new devices retain unknown readings and historical events survive deletion',
      () {
    final controller = SafetyController(devices: [contact()], events: []);
    addTearDown(controller.dispose);
    const pending = SafetyDevice(
        id: 'new',
        title: 'New smoke sensor',
        type: SafetyDeviceType.smoke,
        floorId: 'floor1',
        roomId: 'kitchen',
        location: 'Ceiling');
    controller.saveDevice(pending);
    expect(controller.devices.last.isOnline, isFalse);
    expect(controller.devices.last.batteryPercent, isNull);
    expect(controller.devices.last.stateLabel, 'Unknown');
    controller.removeDevice(pending.id);
    expect(controller.devices.length, 1);
    expect(
        controller.events.where((event) => event.deviceId == 'new').length, 2);
  });

  test('loss of all contact coverage clears the local armed state', () {
    final controller = SafetyController(devices: [contact()], events: []);
    addTearDown(controller.dispose);
    controller.setMode(AlarmMode.home);
    controller.removeDevice('door');
    expect(controller.mode, AlarmMode.disarmed);
    expect(controller.events.first.description, contains('coverage changed'));
  });
}
