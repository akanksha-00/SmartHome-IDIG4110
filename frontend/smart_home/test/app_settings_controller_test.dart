import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/controllers/safety_controller.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';

void main() {
  test('temperature preferences convert display and preserve Celsius storage',
      () {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    expect(settings.formatTemperature(22), '22°C');
    settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    expect(settings.formatTemperature(22, decimals: 1), '71.6°F');
    expect(settings.toCelsius(86), closeTo(30, .00001));
    expect(sampleSafetyDevices[1].temperatureC, 22);
    settings.setTemperatureUnit(TemperatureUnit.celsius);
    expect(settings.formatTemperature(22), '22°C');
  });

  test('notification preferences do not change safety monitoring', () {
    final settings = AppSettingsController();
    final safety = SafetyController(
        devices: sampleSafetyDevices, events: sampleSafetyEvents);
    addTearDown(settings.dispose);
    addTearDown(safety.dispose);
    settings.setOfflineAlerts(false);
    settings.setAutomationUpdates(true);
    settings.setSafetyAlertDelivery({});
    expect(
        safety.devices
            .where((device) => device.isSafetySensor)
            .every((device) => device.isOnline),
        isTrue);
    expect(settings.safetyAlertDelivery, isEmpty);
  });

  test('profile edits update the household owner while protecting ownership',
      () {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    settings.setProfile(
        const ProfileDetails(name: 'Taylor', email: 'taylor@example.com'));
    expect(settings.profile.name, 'Taylor');
    expect(settings.members.first.name, 'Taylor');
    expect(() => settings.removeMember('owner'), throwsArgumentError);
    expect(
        () => settings.setProfile(
            const ProfileDetails(name: 'Taylor', email: 'jamie@example.com')),
        throwsArgumentError);
    expect(
        () => settings.addMember(const HouseholdMember(
            id: 'other',
            name: 'Other',
            email: 'OTHER@example.com',
            role: HouseholdRole.owner)),
        throwsArgumentError);
    expect(
        () => settings.addMember(const HouseholdMember(
            id: 'other',
            name: 'Jamie',
            email: 'JAMIE@example.com',
            role: HouseholdRole.member)),
        throwsArgumentError);
  });

  test('invalid home and timezone values do not replace existing settings', () {
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    expect(() => settings.setHomeName('   '), throwsArgumentError);
    expect(settings.homeName, 'My Home');
    expect(() => settings.setTimeZone('unknown'), throwsArgumentError);
    expect(settings.timeZone, 'Europe/Oslo');
    settings.setTimeZone('UTC');
    expect(settings.timeZone, 'UTC');
  });
}
