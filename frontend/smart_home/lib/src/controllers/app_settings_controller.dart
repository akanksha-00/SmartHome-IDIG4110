import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/settings_data.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';

class AppSettingsController extends ChangeNotifier {
  String _homeName = 'My Home';
  ProfileDetails _profile =
      const ProfileDetails(name: 'Alex', email: 'alex@example.com');
  String _timeZone = 'Europe/Oslo';
  ThemeMode _themeMode = ThemeMode.dark;
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;
  bool _offlineAlerts = true;
  bool _automationUpdates = false;
  Set<AlertDelivery> _delivery = {AlertDelivery.inApp, AlertDelivery.push};
  final _members = List<HouseholdMember>.of(sampleHouseholdMembers);

  String get homeName => _homeName;
  ProfileDetails get profile => _profile;
  String get timeZone => _timeZone;
  ThemeMode get themeMode => _themeMode;
  TemperatureUnit get temperatureUnit => _temperatureUnit;
  bool get offlineAlerts => _offlineAlerts;
  bool get automationUpdates => _automationUpdates;
  Set<AlertDelivery> get safetyAlertDelivery => Set.unmodifiable(_delivery);
  List<HouseholdMember> get members => List.unmodifiable(_members);

  void setHomeName(String value) {
    if (value.trim().isEmpty) throw ArgumentError('Enter a home name');
    _homeName = value.trim();
    notifyListeners();
  }

  void setProfile(ProfileDetails value) {
    if (value.name.trim().isEmpty || !_validEmail(value.email)) {
      throw ArgumentError('Enter a name and valid email');
    }
    if (_members.any((member) =>
        member.role != HouseholdRole.owner &&
        member.email.toLowerCase() == value.email.trim().toLowerCase())) {
      throw ArgumentError('This email is already in the household');
    }
    _profile =
        ProfileDetails(name: value.name.trim(), email: value.email.trim());
    final owner =
        _members.indexWhere((member) => member.role == HouseholdRole.owner);
    _members[owner] = HouseholdMember(
        id: _members[owner].id,
        name: _profile.name,
        email: _profile.email,
        role: HouseholdRole.owner);
    notifyListeners();
  }

  void setTimeZone(String value) {
    if (!settingsTimeZones.contains(value)) {
      throw ArgumentError('Unsupported time zone');
    }
    _timeZone = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  void setTemperatureUnit(TemperatureUnit value) {
    _temperatureUnit = value;
    notifyListeners();
  }

  void setOfflineAlerts(bool value) {
    _offlineAlerts = value;
    notifyListeners();
  }

  void setAutomationUpdates(bool value) {
    _automationUpdates = value;
    notifyListeners();
  }

  void setSafetyAlertDelivery(Set<AlertDelivery> value) {
    _delivery = Set.of(value);
    notifyListeners();
  }

  double displayedTemperature(double celsius) =>
      _temperatureUnit == TemperatureUnit.celsius
          ? celsius
          : celsius * 9 / 5 + 32;
  double toCelsius(double displayed) =>
      _temperatureUnit == TemperatureUnit.celsius
          ? displayed
          : (displayed - 32) * 5 / 9;
  String get temperatureSymbol =>
      _temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F';
  String formatTemperature(double celsius, {int decimals = 0}) =>
      '${displayedTemperature(celsius).toStringAsFixed(decimals)}$temperatureSymbol';

  void addMember(HouseholdMember member) {
    if (member.role == HouseholdRole.owner) {
      throw ArgumentError('The home already has an owner');
    }
    if (member.name.trim().isEmpty || !_validEmail(member.email)) {
      throw ArgumentError('Enter a name and valid email');
    }
    if (_members.any((item) =>
        item.id == member.id ||
        item.email.toLowerCase() == member.email.trim().toLowerCase())) {
      throw ArgumentError('This household member already exists');
    }
    _members.add(HouseholdMember(
        id: member.id,
        name: member.name.trim(),
        email: member.email.trim(),
        role: member.role));
    notifyListeners();
  }

  void removeMember(String id) {
    final matches = _members.where((member) => member.id == id);
    if (matches.isEmpty) return;
    if (matches.first.role == HouseholdRole.owner) {
      throw ArgumentError('The home owner cannot be removed');
    }
    _members.removeWhere((member) => member.id == id);
    notifyListeners();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}

// Shared session preferences. Persistence will be connected with the backend.
final appSettings = AppSettingsController();

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope(
      {super.key,
      required AppSettingsController controller,
      required super.child})
      : super(notifier: controller);
  static AppSettingsController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
          ?.notifier ??
      appSettings;
  static AppSettingsController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppSettingsScope>()?.notifier ??
      appSettings;
}
