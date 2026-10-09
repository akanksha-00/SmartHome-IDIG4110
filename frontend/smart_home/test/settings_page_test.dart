import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/dummyData/automation_data.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/automations/automation_model.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';
import 'package:smart_home/src/screen/automations/widgets/automation_dialog.dart';
import 'package:smart_home/src/screen/settings/settingsPage.dart';
import 'package:smart_home/src/theme/app_theme.dart';

class SettingsHarness extends StatelessWidget {
  const SettingsHarness({super.key, required this.settings, this.home});
  final AppSettingsController settings;
  final Widget? home;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: settings,
      builder: (context, child) => AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: home ?? Scaffold(body: SettingsPage(controller: settings)),
          )));
}

Future<AppSettingsController> openSettings(WidgetTester tester,
    {Size size = const Size(1250, 1300)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = AppSettingsController();
  addTearDown(settings.dispose);
  await tester.pumpWidget(SettingsHarness(settings: settings));
  await tester.pumpAndSettle();
  return settings;
}

Future<void> clickVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search finds individual preferences and handles no matches',
      (tester) async {
    await openSettings(tester);
    final search = find.byKey(const ValueKey('settings-search'));
    await tester.enterText(search, 'temperature');
    await tester.pumpAndSettle();
    expect(find.text('Appearance & preferences'), findsOneWidget);
    expect(find.text('Temperature unit'), findsOneWidget);
    expect(find.text('Household access'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    await tester.enterText(search, 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text('No settings match your search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and profile editors validate then update their settings',
      (tester) async {
    final settings = await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-row-home-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('settings-home-name')), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a home name'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('settings-home-name')), 'Our Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.homeName, 'Our Home');
    await clickVisible(
        tester, find.byKey(const ValueKey('settings-row-profile')));
    await tester.enterText(
        find.byKey(const ValueKey('settings-profile-name')), 'Taylor');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.profile.name, 'Taylor');
    expect(find.text('Taylor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme and unit controls update shared preferences',
      (tester) async {
    final settings = await openSettings(tester);
    final theme = find.byKey(const ValueKey('settings-theme'));
    await clickVisible(
        tester, find.descendant(of: theme, matching: find.text('Light')));
    expect(settings.themeMode, ThemeMode.light);
    expect(Theme.of(tester.element(theme)).brightness, Brightness.light);
    await clickVisible(
        tester, find.descendant(of: theme, matching: find.text('System')));
    expect(settings.themeMode, ThemeMode.system);
    final units = find.byKey(const ValueKey('settings-temperature'));
    await clickVisible(
        tester, find.descendant(of: units, matching: find.text('°F')));
    expect(settings.temperatureUnit, TemperatureUnit.fahrenheit);
    expect(settings.formatTemperature(22), '72°F');
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications and delivery choices are saved', (tester) async {
    final settings = await openSettings(tester);
    await clickVisible(
        tester, find.byKey(const ValueKey('settings-switch-offline')));
    expect(settings.offlineAlerts, isFalse);
    await clickVisible(
        tester, find.byKey(const ValueKey('settings-row-safety-delivery')));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Email alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.safetyAlertDelivery, contains(AlertDelivery.email));
    expect(tester.takeException(), isNull);
  });

  testWidgets('household owner is protected and new members can be added',
      (tester) async {
    final settings = await openSettings(tester);
    await clickVisible(
        tester, find.byKey(const ValueKey('settings-row-members')));
    expect(find.byTooltip('Remove Alex'), findsNothing);
    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('settings-profile-name')), 'Morgan');
    await tester.enterText(find.byKey(const ValueKey('settings-profile-email')),
        'morgan@example.com');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.members.length, 3);
    expect(find.text('Morgan'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Morgan'));
    await tester.pumpAndSettle();
    expect(settings.members.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'time zone picker updates preference and actual floor list is shown',
      (tester) async {
    final settings = await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-row-time-zone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTC'));
    await tester.pumpAndSettle();
    expect(settings.timeZone, 'UTC');
    expect(find.text('1 floor · 4 rooms'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-row-rooms')));
    await tester.pumpAndSettle();
    expect(find.text('Floor 1'), findsOneWidget);
    expect(find.text('Bedroom 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fahrenheit automation inputs are saved as Celsius',
      (tester) async {
    final settings = AppSettingsController()
      ..setTemperatureUnit(TemperatureUnit.fahrenheit);
    addTearDown(settings.dispose);
    AutomationModel? saved;
    await tester.pumpWidget(SettingsHarness(
        settings: settings,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async {
                        saved = await showDialog<AutomationModel>(
                            context: context,
                            builder: (context) => AutomationDialog(
                                devices: createSmartDevices(),
                                automation: createSampleAutomations()[2]));
                      },
                      child: const Text('Edit temperature'),
                    )))));
    await tester.tap(find.text('Edit temperature'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('automation-temperature'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '78.8');
    await tester.enterText(field, '86');
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(saved!.trigger.temperatureC, closeTo(30, .00001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings and editor fit a narrow viewport', (tester) async {
    await openSettings(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);
    await clickVisible(
        tester, find.byKey(const ValueKey('settings-row-home-name')));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
