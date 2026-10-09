import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/dummyData/automation_data.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/automations/automation_model.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';

void main() {
  test('sample routine targets belong to their room and support the action',
      () {
    final devices = {
      for (final device in createSmartDevices()) device.id: device
    };
    for (final routine in createSampleAutomations()) {
      for (final id in routine.action.deviceIds) {
        final device = devices[id];
        expect(device, isNotNull);
        expect(device!.roomId, routine.roomId);
        if (routine.action.type == AutomationActionType.brightness) {
          expect(device, isA<LightDeviceModel>());
        }
        if (routine.action.type == AutomationActionType.fanSpeed) {
          expect(device, isA<FanDeviceModel>());
        }
      }
    }
  });

  test('invalid actions cannot create misleading device commands', () {
    expect(
        () =>
            AutomationAction(type: AutomationActionType.turnOn, deviceIds: []),
        throwsArgumentError);
    expect(
        () => AutomationAction(
            type: AutomationActionType.turnOff, deviceIds: ['a', 'a']),
        throwsArgumentError);
    expect(
        () => AutomationAction(
            type: AutomationActionType.fanSpeed, deviceIds: ['a'], level: 4),
        throwsArgumentError);
    expect(
        () => AutomationAction(
            type: AutomationActionType.brightness,
            deviceIds: ['a'],
            level: 101),
        throwsArgumentError);
  });
}
