import 'package:flutter/material.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/screen/home/widgets/fanDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/lightDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/smartPlugDeviceCard.dart';

/// Adapts backend capability bounds to the existing card widgets.
class ApiDeviceCard extends StatelessWidget {
  const ApiDeviceCard({
    super.key,
    required this.device,
    required this.subtitle,
    required this.onStateChanged,
    this.isUpdating = false,
  });

  final ApiDevice device;
  final String subtitle;
  final bool isUpdating;
  final ValueChanged<Map<String, Object?>> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final isOn = device.state['power'] == true;
    final canUpdate = !isUpdating && device.status['operational'] != false;
    final power = canUpdate &&
            device.capabilities['power']?.type == 'boolean' &&
            device.state['power'] is bool
        ? (bool value) => onStateChanged({'power': value})
        : null;

    switch (device.type.toLowerCase()) {
      case 'light':
        final capability = device.capabilities['brightness'];
        final min = capability?.min ?? 0;
        final max = capability?.max ?? 100;
        final raw = device.state['brightness'];
        final hasBrightness =
            capability != null && raw is num && raw.isFinite && max > min;
        final value =
            hasBrightness ? ((raw - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
        return LightDeviceCard(
          title: device.name,
          subtitle: subtitle,
          isOn: isOn,
          brightness: value,
          onPowerChanged: power,
          onBrightnessChanged: canUpdate && hasBrightness
              ? (value) {
                  final scaled = min + value * (max - min);
                  onStateChanged({
                    // Keep an on light powered when its brightness changes.
                    if (device.capabilities['power']?.type == 'boolean' &&
                        device.state['power'] is bool)
                      'power': isOn,
                    'brightness':
                        capability.type == 'integer' ? scaled.round() : scaled
                  });
                }
              : null,
        );
      case 'fan':
        final capability = device.capabilities['speed'];
        final min = capability?.min;
        final max = capability?.max;
        final raw = device.state['speed'];
        // Only show declared, integral speeds. Large ranges use a read-only label.
        final hasSpeeds = capability?.type == 'integer' &&
            min != null &&
            max != null &&
            min.isFinite &&
            max.isFinite &&
            min == min.round() &&
            max == max.round() &&
            max >= min &&
            max - min < 10;
        final values = hasSpeeds
            ? [
                for (var value = min.toInt(); value <= max.toInt(); value++)
                  value
              ]
            : <int>[];
        return FanDeviceCard(
          title: device.name,
          subtitle: subtitle,
          isOn: isOn,
          speed: raw is num && raw.isFinite ? raw.toInt() : 0,
          speedValues: values,
          onPowerChanged: power,
          onSpeedChanged: canUpdate && hasSpeeds
              ? (value) => onStateChanged({'speed': value})
              : null,
        );
      case 'plug':
      case 'smart_plug':
        return SmartPlugDeviceCard(
          title: device.name,
          subtitle: subtitle,
          isOn: isOn,
          onPowerChanged: power,
        );
      case 'smoke_detector':
      case 'temperature_sensor':
        final smoke = device.type.toLowerCase() == 'smoke_detector';
        final value = device.state[smoke ? 'smoke' : 'temperature'];
        final reading = smoke
            ? (value is bool
                ? (value ? 'Smoke detected' : 'No smoke detected')
                : 'No reading')
            : (value is num && value.isFinite
                ? '${value.toStringAsFixed(1)}°C'
                : 'No reading');
        return Card(
            child: ListTile(
          leading: Icon(smoke ? Icons.sensors : Icons.thermostat,
              color: smoke && value == true
                  ? Colors.redAccent
                  : Theme.of(context).colorScheme.primary),
          title: Text(device.name),
          subtitle: Text(
              '$subtitle · ${device.status['operational'] == false ? 'Offline' : reading}'),
        ));
      default:
        return Card(
            child: ListTile(
          leading: const Icon(Icons.devices_other),
          title: Text(device.name),
          subtitle: Text('$subtitle · ${device.type}'),
          trailing:
              power == null ? null : Switch(value: isOn, onChanged: power),
        ));
    }
  }
}
