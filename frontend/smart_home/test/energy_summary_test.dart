import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/dummyData/energyData.dart';
import 'package:smart_home/src/models/energy/energyUsageModel.dart';

DeviceEnergyUsage reading(String id, List<double>? current,
        {List<double>? previous}) =>
    DeviceEnergyUsage(
      id: id,
      title: id,
      floorId: 'floor1',
      roomId: 'living',
      roomName: 'Living Room',
      type: EnergyDeviceType.plug,
      runtimeHours: 1,
      energyKwh: current,
      previousEnergyKwh: previous,
    );

EnergyPeriodData period(List<DeviceEnergyUsage> devices) => EnergyPeriodData(
      id: 'test',
      chartTitle: 'Test readings',
      caption: 'Test',
      previousPeriodLabel: 'previous',
      bucketLabels: const ['1', '2'],
      fullBucketLabels: const ['Day 1', 'Day 2'],
      devices: devices,
    );

void main() {
  test('weekly cards, chart and device totals agree', () {
    final summary = EnergySummary.fromPeriod(sampleEnergyPeriods['week']!);
    expect(summary.totalEnergyKwh, closeTo(58.8, .00001));
    expect(summary.previousEnergyKwh, closeTo(66.8, .00001));
    expect(summary.changePercent, closeTo(-11.976, .001));
    expect(summary.reportingDeviceCount, 5);
    expect(summary.devices.length, 7);
    expect(summary.peakIndex, 5);
    final tableTotal = summary.devices
        .fold<double>(0, (sum, device) => sum + (device.totalEnergyKwh ?? 0));
    expect(tableTotal, closeTo(summary.totalEnergyKwh!, .00001));
  });

  test('room and floor filters apply before aggregation', () {
    final week = sampleEnergyPeriods['week']!;
    final bedroom =
        EnergySummary.fromPeriod(week, floorId: 'floor1', roomId: 'bedroom1');
    final living = EnergySummary.fromPeriod(week, roomId: 'living');
    expect(bedroom.devices.length, 1);
    expect(bedroom.totalEnergyKwh, closeTo(8.82, .00001));
    expect(living.devices.length, 6);
    expect(living.totalEnergyKwh, closeTo(49.98, .00001));
    for (final empty in [
      EnergySummary.fromPeriod(week, roomId: 'kitchen'),
      EnergySummary.fromPeriod(week, floorId: 'missing'),
    ]) {
      expect(empty.devices, isEmpty);
      expect(empty.totalEnergyKwh, isNull);
      expect(empty.peakIndex, isNull);
      expect(empty.changePercent, isNull);
    }
  });

  test('periods provide different series and totals', () {
    final today = EnergySummary.fromPeriod(sampleEnergyPeriods['today']!);
    final month = EnergySummary.fromPeriod(sampleEnergyPeriods['month']!);
    expect(today.energyByInterval.length, 24);
    expect(today.totalEnergyKwh, closeTo(8.4, .00001));
    expect(month.energyByInterval.length, 30);
    expect(month.totalEnergyKwh, greaterThan(58.8));
    expect(month.changePercent, greaterThan(0));
  });

  test('missing readings are distinct from measured zero', () {
    final missing =
        EnergySummary.fromPeriod(period([reading('unmetered', null)]));
    final zero = EnergySummary.fromPeriod(period([
      reading('metered', [0, 0], previous: [0, 0]),
    ]));
    expect(missing.devices.length, 1);
    expect(missing.reportingDeviceCount, 0);
    expect(missing.totalEnergyKwh, isNull);
    expect(zero.reportingDeviceCount, 1);
    expect(zero.totalEnergyKwh, 0);
    expect(zero.peakIndex, isNull);
    expect(zero.changePercent, isNull);
  });

  test('incomplete previous coverage does not show a false reduction', () {
    final summary = EnergySummary.fromPeriod(period([
      reading('a', [1, 2], previous: [4, 5]),
      reading('b', [2, 3]),
      reading('unmetered', null),
    ]));
    expect(summary.totalEnergyKwh, 8);
    expect(summary.reportingDeviceCount, 2);
    expect(summary.previousEnergyKwh, isNull);
    expect(summary.changePercent, isNull);
  });

  test('invalid interval readings are rejected', () {
    expect(
        () => period([
              reading('short', [1])
            ]),
        throwsArgumentError);
    expect(
        () => period([
              reading('negative', [1, -1])
            ]),
        throwsArgumentError);
  });
}
