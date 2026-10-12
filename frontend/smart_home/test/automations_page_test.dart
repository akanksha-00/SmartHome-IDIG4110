import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/screen/automations/automations_page.dart';
import 'package:smart_home/src/theme/app_theme.dart';

Future<void> openAutomations(WidgetTester tester,
    {Size size = const Size(1250, 1200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: const Scaffold(body: AutomationsPage()),
  ));
  await tester.pumpAndSettle();
}

Finder card(String id) => find.byKey(ValueKey('automation-card-$id'));
Finder targets(String id) => find.byKey(ValueKey('automation-target-$id'));

void main() {
  testWidgets('pausing updates status counts and filters', (tester) async {
    await openAutomations(tester);
    expect(find.text('All  4'), findsOneWidget);
    expect(find.text('Enabled  3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('automation-switch-morning')));
    await tester.pumpAndSettle();
    expect(find.text('Enabled  2'), findsOneWidget);
    expect(find.text('Paused  2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('automation-status-Paused')));
    await tester.pumpAndSettle();
    expect(card('morning'), findsOneWidget);
    expect(card('bedtime'), findsOneWidget);
    expect(card('evening'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and room filters produce useful empty states',
      (tester) async {
    await openAutomations(tester);
    final search = find.byKey(const ValueKey('automation-search'));
    await tester.enterText(search, 'cool');
    await tester.pumpAndSettle();
    expect(card('cool'), findsOneWidget);
    expect(card('morning'), findsNothing);
    expect(find.text('All  1'), findsOneWidget);
    await tester.enterText(search, 'no matching routine');
    await tester.pumpAndSettle();
    expect(find.text('No automations match your filters'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('automation-room-filter-all-all')),
      matching: find.byType(TextField),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen').last);
    await tester.pumpAndSettle();
    expect(find.text('All  0'), findsOneWidget);
    expect(find.text('No runs in this selection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding validates name and targets then displays the new routine',
      (tester) async {
    await openAutomations(tester);
    await tester.tap(find.byKey(const ValueKey('add-automation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an automation name'), findsOneWidget);
    expect(find.text('Choose at least one device'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('automation-name')), 'Movie time');
    expect(
        targets('light-1'), findsNothing); // This light belongs to Bedroom 1.
    await tester.ensureVisible(targets('smart-plug-1'));
    await tester.pumpAndSettle();
    await tester.tap(targets('smart-plug-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(find.text('Movie time'), findsOneWidget);
    expect(find.text('All  5'), findsOneWidget);
    expect(find.text('TV Plug → On'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit retains the ID and deletion retains recorded history',
      (tester) async {
    await openAutomations(tester);
    await tester.tap(find.byKey(const ValueKey('automation-menu-morning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('automation-name')), 'Morning routine');
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(card('morning'), findsOneWidget);
    expect(find.text('All  4'), findsOneWidget);
    expect(find.text('Morning routine'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('automation-menu-morning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(card('morning'), findsNothing);
    expect(find.text('All  3'), findsOneWidget);
    await tester.tap(find.text('View history'));
    await tester.pumpAndSettle();
    expect(find.text('Run history'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Morning lights')),
        findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing action removes incompatible target selections',
      (tester) async {
    await openAutomations(tester);
    await tester.tap(find.byKey(const ValueKey('add-automation')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('automation-name')), 'Fan routine');
    await tester.ensureVisible(targets('smart-plug-1'));
    await tester.pumpAndSettle();
    await tester.tap(targets('smart-plug-1'));
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('automation-action'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set fan speed').last);
    await tester.pumpAndSettle();
    expect(targets('smart-plug-1'), findsNothing);
    expect(targets('light-2'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(find.text('Choose at least one device'), findsOneWidget);
    await tester.ensureVisible(targets('fan-1'));
    await tester.pumpAndSettle();
    await tester.tap(targets('fan-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automation-save')));
    await tester.pumpAndSettle();
    expect(find.text('Fan 1 → On, speed 2'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('page and editor fit a narrow screen', (tester) async {
    await openAutomations(tester, size: const Size(360, 800));
    expect(card('morning'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('add-automation')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('All  4'), findsOneWidget);
  });
}
