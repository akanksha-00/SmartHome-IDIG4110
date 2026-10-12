import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/screen/energy/energyPage.dart';
import 'package:smart_home/src/theme/app_theme.dart';

Future<void> openEnergy(WidgetTester tester,
    {Size size = const Size(1200, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: const Scaffold(body: EnergyPage()),
  ));
  await tester.pumpAndSettle();
}

String cardValue(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('period buttons update chart and summary together',
      (tester) async {
    await openEnergy(tester);
    expect(cardValue(tester, 'energy-total'), '58.8 kWh');
    expect(cardValue(tester, 'energy-peak'), 'Saturday');
    expect(find.byType(LineChart), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Hourly energy usage'), findsOneWidget);
    expect(cardValue(tester, 'energy-total'), '8.4 kWh');
    expect(cardValue(tester, 'energy-peak'), '18:00');
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('30 daily sample readings'), findsOneWidget);
    expect(cardValue(tester, 'energy-comparison'), startsWith('+'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('room filtering handles rooms without sample devices',
      (tester) async {
    await openEnergy(tester);
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('energy-room-all')),
      matching: find.byType(TextField),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitchen').last);
    await tester.pumpAndSettle();
    expect(cardValue(tester, 'energy-total'), '—');
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No devices in this selection'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device search and energy sorting retain the period total',
      (tester) async {
    await openEnergy(tester);
    final search = find.byKey(const ValueKey('energy-device-search'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'TV');
    await tester.pumpAndSettle();
    var table = tester
        .widget<DataTable>(find.byKey(const ValueKey('energy-device-table')));
    expect(table.rows.length, 1);
    expect(table.rows.single.key, const ValueKey('smart-plug-1'));
    expect(cardValue(tester, 'energy-total'), '58.8 kWh');
    await tester.enterText(search, 'missing device');
    await tester.pumpAndSettle();
    expect(find.text('No devices match your search'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    table = tester
        .widget<DataTable>(find.byKey(const ValueKey('energy-device-table')));
    table.columns[3].onSort!(3, false);
    await tester.pumpAndSettle();
    table = tester
        .widget<DataTable>(find.byKey(const ValueKey('energy-device-table')));
    expect(table.rows.first.key, const ValueKey('smart-plug-1'));
    expect(table.rows.last.key, const ValueKey('light-3'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout stacks cards and scrolls the table',
      (tester) async {
    await openEnergy(tester, size: const Size(320, 800));
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
    final search = find.byKey(const ValueKey('energy-device-search'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('energy-device-table')), findsOneWidget);
  });
}
