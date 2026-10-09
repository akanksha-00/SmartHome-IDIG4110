import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/controllers/safety_controller.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';
import 'package:smart_home/src/screen/safety/safety_page.dart';
import 'package:smart_home/src/theme/app_theme.dart';

Future<void> openSafety(WidgetTester tester,
    {Size size = const Size(1400, 1400), SafetyController? controller}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SafetyPage(controller: controller))));
  await tester.pumpAndSettle();
}

Finder device(String id) => find.byKey(ValueKey('safety-device-$id'));

void main() {
  testWidgets(
      'overview separates intrusion from safety and reviews open contacts',
      (tester) async {
    await openSafety(tester);
    expect(find.text('Intrusion: Disarmed'), findsOneWidget);
    expect(find.text('Safety monitoring active'), findsOneWidget);
    expect(find.text('4 of 4 safety sensors reporting'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arm-away')));
    await tester.pumpAndSettle();
    expect(find.text('Review devices before arming'), findsOneWidget);
    expect(find.text('Kitchen window must be closed.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-review')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Open')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready sensor readings allow mode changes and event history',
      (tester) async {
    final controller = SafetyController(devices: [
      const SafetyDevice(
        id: 'door',
        title: 'Front door',
        type: SafetyDeviceType.door,
        floorId: 'floor1',
        roomId: 'living',
        location: 'Entrance',
        state: SafetyDeviceState.closed,
        isOnline: true,
      ),
      sampleSafetyDevices.first
    ], events: []);
    addTearDown(controller.dispose);
    await openSafety(tester, controller: controller);
    await tester.tap(find.byKey(const ValueKey('arm-home')));
    await tester.pumpAndSettle();
    expect(find.text('Intrusion: Armed home'), findsOneWidget);
    expect(find.text('Intrusion armed home'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('disarm')));
    await tester.pumpAndSettle();
    expect(find.text('Intrusion: Disarmed'), findsOneWidget);
    expect(find.text('Safety monitoring active'), findsOneWidget);
    expect(controller.events.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search filters both device groups and show-all reveals hidden devices',
      (tester) async {
    await openSafety(tester);
    expect(device('window-2'), findsNothing);
    final viewAll = find.byKey(const ValueKey('safety-view-all'));
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();
    expect(device('window-2'), findsOneWidget);
    final search = find.byKey(const ValueKey('safety-search'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'window');
    await tester.pumpAndSettle();
    expect(device('window-1'), findsOneWidget);
    expect(device('window-2'), findsOneWidget);
    expect(device('smoke-1'), findsNothing);
    expect(device('door-1'), findsNothing);
    await tester.enterText(search, 'no matching sensor');
    await tester.pumpAndSettle();
    expect(find.text('No devices match your filters'), findsNWidgets(2));
    // Whole-house safety coverage is independent of the search results.
    expect(find.text('4 of 4 safety sensors reporting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room selection scopes devices and event history',
      (tester) async {
    await openSafety(tester);
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('safety-room-filter-all-all')),
        matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen').last);
    await tester.pumpAndSettle();
    expect(device('smoke-1'), findsOneWidget);
    expect(device('co-1'), findsNothing);
    expect(device('window-1'), findsOneWidget);
    expect(find.text('Front door locked'), findsNothing);
    await tester.tap(find.text('View history'));
    await tester.pumpAndSettle();
    expect(find.text('Event history'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Kitchen window opened')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'adding a device validates fields and never invents normal readings',
      (tester) async {
    await openSafety(tester);
    await tester.tap(find.byKey(const ValueKey('safety-add-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-device-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a device name'), findsOneWidget);
    expect(find.text('Enter a location'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('safety-device-name')), 'Extra smoke alarm');
    await tester.enterText(
        find.byKey(const ValueKey('safety-device-location')), 'Near the sofa');
    await tester.tap(find.byKey(const ValueKey('safety-device-save')));
    await tester.pumpAndSettle();
    expect(find.text('Extra smoke alarm'), findsOneWidget);
    expect(find.text('Safety monitoring incomplete'), findsOneWidget);
    expect(find.text('4 of 5 safety sensors reporting'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device details support editing while preserving sensor state',
      (tester) async {
    await openSafety(tester);
    await tester.tap(device('smoke-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('safety-device-name')), 'Kitchen smoke');
    await tester.tap(find.byKey(const ValueKey('safety-device-save')));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen smoke'), findsOneWidget);
    expect(find.text('4 of 4 safety sensors reporting'), findsOneWidget);
    expect(device('smoke-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen and device dialog remain usable', (tester) async {
    await openSafety(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('safety-add-device')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final row = device('smoke-1');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
