enum EnergyDeviceType { light, fan, plug }

class DeviceEnergyUsage {
  DeviceEnergyUsage({
    required this.id,
    required this.title,
    required this.floorId,
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.runtimeHours,
    List<double>? energyKwh,
    List<double>? previousEnergyKwh,
  })  : energyKwh = energyKwh == null ? null : List.unmodifiable(energyKwh),
        previousEnergyKwh = previousEnergyKwh == null
            ? null
            : List.unmodifiable(previousEnergyKwh);

  final String id;
  final String title;
  final String floorId;
  final String roomId;
  final String roomName;
  final EnergyDeviceType type;
  final double runtimeHours;

  // Each value is energy consumed during one chart interval, not a meter total.
  // Null means the device does not supply energy readings; zero is a reading.
  final List<double>? energyKwh;
  final List<double>? previousEnergyKwh;

  double? get totalEnergyKwh =>
      energyKwh?.fold<double>(0, (total, value) => total + value);
}

class EnergyPeriodData {
  EnergyPeriodData({
    required this.id,
    required this.chartTitle,
    required this.caption,
    required this.previousPeriodLabel,
    required List<String> bucketLabels,
    required List<String> fullBucketLabels,
    required List<DeviceEnergyUsage> devices,
  })  : bucketLabels = List.unmodifiable(bucketLabels),
        fullBucketLabels = List.unmodifiable(fullBucketLabels),
        devices = List.unmodifiable(devices) {
    if (bucketLabels.isEmpty ||
        bucketLabels.length != fullBucketLabels.length) {
      throw ArgumentError(
          'Energy intervals need matching short and full labels.');
    }
    for (final device in devices) {
      for (final readings in [device.energyKwh, device.previousEnergyKwh]) {
        if (readings != null &&
            (readings.length != bucketLabels.length ||
                readings.any((value) => !value.isFinite || value < 0))) {
          throw ArgumentError('Invalid interval readings for ${device.id}.');
        }
      }
    }
  }

  final String id;
  final String chartTitle;
  final String caption;
  final String previousPeriodLabel;
  final List<String> bucketLabels;
  final List<String> fullBucketLabels;
  final List<DeviceEnergyUsage> devices;
}

class EnergySummary {
  EnergySummary._({
    required this.period,
    required this.devices,
    required this.energyByInterval,
    required this.previousEnergyByInterval,
    required this.reportingDeviceCount,
  });

  factory EnergySummary.fromPeriod(
    EnergyPeriodData period, {
    String floorId = 'all',
    String roomId = 'all',
  }) {
    final devices = period.devices.where((device) {
      return (floorId == 'all' || device.floorId == floorId) &&
          (roomId == 'all' || device.roomId == roomId);
    }).toList();
    final reporting =
        devices.where((device) => device.energyKwh != null).toList();
    final current = List<double>.generate(
      period.bucketLabels.length,
      (index) => reporting.fold<double>(
        0,
        (total, device) => total + device.energyKwh![index],
      ),
    );

    // Compare the same reporting devices in both periods. Partial coverage
    // should not appear as a reduction in energy consumption.
    final hasPrevious = reporting.isNotEmpty &&
        reporting.every((device) => device.previousEnergyKwh != null);
    final previous = hasPrevious
        ? List<double>.generate(
            period.bucketLabels.length,
            (index) => reporting.fold<double>(
              0,
              (total, device) => total + device.previousEnergyKwh![index],
            ),
          )
        : null;

    return EnergySummary._(
      period: period,
      devices: List.unmodifiable(devices),
      energyByInterval: List.unmodifiable(current),
      previousEnergyByInterval:
          previous == null ? null : List.unmodifiable(previous),
      reportingDeviceCount: reporting.length,
    );
  }

  final EnergyPeriodData period;
  final List<DeviceEnergyUsage> devices;
  final List<double> energyByInterval;
  final List<double>? previousEnergyByInterval;
  final int reportingDeviceCount;

  double? get totalEnergyKwh => reportingDeviceCount == 0
      ? null
      : energyByInterval.fold<double>(0, (total, value) => total + value);

  double? get previousEnergyKwh => previousEnergyByInterval?.fold<double>(
      0, (total, value) => total + value);

  double? get changePercent {
    final current = totalEnergyKwh;
    final previous = previousEnergyKwh;
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  int? get peakIndex {
    if (totalEnergyKwh == null || totalEnergyKwh == 0) return null;
    var highest = 0;
    for (var index = 1; index < energyByInterval.length; index++) {
      if (energyByInterval[index] > energyByInterval[highest]) highest = index;
    }
    return highest;
  }
}
