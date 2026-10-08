import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';

IconData safetyDeviceIcon(SafetyDeviceType type) => switch (type) {
      SafetyDeviceType.smoke => Icons.sensors_outlined,
      SafetyDeviceType.heat => Icons.thermostat_outlined,
      SafetyDeviceType.carbonMonoxide => Icons.bubble_chart_outlined,
      SafetyDeviceType.waterLeak => Icons.water_drop_outlined,
      SafetyDeviceType.door => Icons.door_front_door_outlined,
      SafetyDeviceType.window => Icons.window_outlined,
      SafetyDeviceType.motion => Icons.directions_walk,
    };

class SafetyStateBadge extends StatelessWidget {
  const SafetyStateBadge({super.key, required this.device});
  final SafetyDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unknown =
        !device.isOnline || device.state == SafetyDeviceState.unknown;
    final color = unknown
        ? colors.onSurfaceVariant
        : device.isAlert
            ? colors.primary
            : Theme.of(context).brightness == Brightness.dark
                ? Colors.greenAccent
                : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(20)),
      child:
          Text(device.stateLabel, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class SafetyDeviceTile extends StatelessWidget {
  const SafetyDeviceTile(
      {super.key, required this.device, required this.onTap});
  final SafetyDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onlineColor = device.isOnline
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade700)
        : colors.onSurfaceVariant;
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(device.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(
          '${safetyRoomLabels[device.roomId] ?? device.roomId} · ${device.location}',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
    ]);
    final statuses = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (device.isOnline && device.temperatureC != null)
            Text(AppSettingsScope.of(context)
                .formatTemperature(device.temperatureC!)),
          SafetyStateBadge(device: device),
          if (device.isOnline && device.isLocked != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(device.isLocked! ? Icons.lock_outline : Icons.lock_open,
                    size: 14),
                const SizedBox(width: 4),
                Text(device.isLocked! ? 'Locked' : 'Unlocked',
                    style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ]);
    final health = Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 8, color: onlineColor),
            const SizedBox(width: 6),
            Text(device.isOnline ? 'Online' : 'Offline',
                style: TextStyle(color: onlineColor, fontSize: 12)),
          ]),
          Tooltip(
              message: device.batteryPercent == null
                  ? 'Battery reading unavailable'
                  : 'Battery: ${device.batteryPercent}%',
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    device.hasLowBattery
                        ? Icons.battery_alert_outlined
                        : Icons.battery_std,
                    size: 16,
                    color: device.hasLowBattery
                        ? colors.primary
                        : colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                    device.batteryPercent == null
                        ? '—'
                        : '${device.batteryPercent}%',
                    style: TextStyle(
                        fontSize: 12,
                        color: device.hasLowBattery
                            ? colors.primary
                            : colors.onSurfaceVariant)),
              ])),
        ]);
    return Container(
      decoration: BoxDecoration(
        color: device.needsAttention
            ? colors.primary.withValues(alpha: .04)
            : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: device.needsAttention ? colors.primary : colors.outline),
      ),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, constraints) {
                final icon = Icon(safetyDeviceIcon(device.type), size: 28);
                if (constraints.maxWidth >= 650) {
                  return Row(children: [
                    icon,
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: identity),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: statuses),
                    const SizedBox(width: 12),
                    health,
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, size: 20),
                  ]);
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: identity),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 20)
                      ]),
                      const SizedBox(height: 12),
                      statuses,
                      const SizedBox(height: 10),
                      health,
                    ]);
              }),
            ),
          )),
    );
  }
}
