import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/energy/energyUsageModel.dart';

const List<double> weeklyEnergyKwh = [
  7.4,
  8.1,
  9.2,
  7.8,
  8.5,
  9.4,
  8.4,
];

const List<String> weekDayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const double previousWeekEnergyKwh = 66.8;

const Map<String, String> energyFloorLabels = {'floor1': 'Floor 1'};
const Map<String, String> energyRoomLabels = {
  'living': 'Living Room',
  'kitchen': 'Kitchen',
  'bedroom1': 'Bedroom 1',
  'bathroom1': 'Bathroom 1',
};

// Demonstration readings only. Device identities come from the same sample
// inventory as Home; no live power readings are inferred from on/off state.
final Map<String, EnergyPeriodData> sampleEnergyPeriods =
    _createSamplePeriods();

Map<String, EnergyPeriodData> _createSamplePeriods() {
  const hourlyPattern = [
    .1,
    .1,
    .08,
    .08,
    .1,
    .2,
    .3,
    .7,
    .6,
    .3,
    .25,
    .4,
    .65,
    .5,
    .4,
    .35,
    .4,
    .65,
    1.15,
    .95,
    .7,
    .5,
    .25,
    .2,
  ];
  final hourlyTotal =
      hourlyPattern.fold<double>(0, (sum, value) => sum + value);
  final hourly =
      hourlyPattern.map((value) => value / hourlyTotal * 8.4).toList();
  final monthly = List<double>.generate(
    30,
    (index) => weeklyEnergyKwh[index % 7] * (1 + (index % 3) * .025),
  );

  return {
    'today': _createPeriod(
      id: 'today',
      chartTitle: 'Hourly energy usage',
      caption: '24 hourly sample readings',
      previousPeriodLabel: 'yesterday',
      labels:
          List.generate(24, (hour) => '${hour.toString().padLeft(2, '0')}:00'),
      fullLabels: List.generate(24, (hour) {
        final start = hour.toString().padLeft(2, '0');
        final end = ((hour + 1) % 24).toString().padLeft(2, '0');
        return '$start:00 – $end:00';
      }),
      energy: hourly,
      previousFactor: 1.1,
      runtimeFactor: 1 / 7,
    ),
    'week': _createPeriod(
      id: 'week',
      chartTitle: 'Daily energy usage',
      caption: 'Monday–Sunday · sample readings',
      previousPeriodLabel: 'last week',
      labels: weekDayLabels,
      fullLabels: const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ],
      energy: weeklyEnergyKwh,
      previousFactor: previousWeekEnergyKwh /
          weeklyEnergyKwh.fold<double>(0, (sum, value) => sum + value),
      runtimeFactor: 1,
    ),
    'month': _createPeriod(
      id: 'month',
      chartTitle: 'Daily energy usage',
      caption: '30 daily sample readings',
      previousPeriodLabel: 'last month',
      labels: List.generate(30, (index) => '${index + 1}'),
      fullLabels: List.generate(30, (index) => 'Day ${index + 1}'),
      energy: monthly,
      previousFactor: .94,
      runtimeFactor: 30 / 7,
    ),
  };
}

EnergyPeriodData _createPeriod({
  required String id,
  required String chartTitle,
  required String caption,
  required String previousPeriodLabel,
  required List<String> labels,
  required List<String> fullLabels,
  required List<double> energy,
  required double previousFactor,
  required double runtimeFactor,
}) {
  const energyShares = {
    'light-1': .15,
    'fan-1': .15,
    'fan-2': .12,
    'smart-plug-1': .4,
    'smart-plug-2': .18,
  };
  const weeklyRuntimeHours = {
    'light-1': 21.0,
    'light-2': 14.0,
    'light-3': 8.0,
    'fan-1': 35.0,
    'fan-2': 28.0,
    'smart-plug-1': 28.0,
    'smart-plug-2': 17.0,
  };
  final devices = createSmartDevices().map((device) {
    final share = energyShares[device.id];
    return DeviceEnergyUsage(
      id: device.id,
      title: device.title,
      floorId: 'floor1',
      roomId: device.roomId,
      roomName: energyRoomLabels[device.roomId] ?? device.roomId,
      type: device is LightDeviceModel
          ? EnergyDeviceType.light
          : device is FanDeviceModel
              ? EnergyDeviceType.fan
              : EnergyDeviceType.plug,
      runtimeHours: (weeklyRuntimeHours[device.id] ?? 0) * runtimeFactor,
      energyKwh:
          share == null ? null : energy.map((value) => value * share).toList(),
      previousEnergyKwh: share == null
          ? null
          : energy.map((value) => value * share * previousFactor).toList(),
    );
  }).toList();

  return EnergyPeriodData(
    id: id,
    chartTitle: chartTitle,
    caption: caption,
    previousPeriodLabel: previousPeriodLabel,
    bucketLabels: labels,
    fullBucketLabels: fullLabels,
    devices: devices,
  );
}
