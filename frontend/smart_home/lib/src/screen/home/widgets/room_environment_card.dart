import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';

/// Uses reported sensor state. Other metrics stay empty until their backend
/// capabilities are defined; sample values must not look like live readings.
class RoomEnvironmentCard extends StatelessWidget {
  const RoomEnvironmentCard({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) => BlocBuilder<DeviceBloc, DeviceState>(
        buildWhen: (previous, current) => previous.devices != current.devices,
        builder: (context, state) {
          final sensors = state.devices.where((device) =>
              device.roomId == roomId &&
              device.type == 'temperature_sensor' &&
              device.status['operational'] != false &&
              device.state['temperature'] is num &&
              (device.state['temperature'] as num).isFinite);
          final sensor = sensors.firstOrNull;
          final temperature = sensor?.state['temperature'] as num?;
          return SizedBox(
              width: 280,
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Room environment',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _row(Icons.air, 'Air quality', '—'),
                      const SizedBox(height: 14),
                      _row(
                          Icons.thermostat,
                          'Temperature',
                          temperature == null
                              ? '—'
                              : AppSettingsScope.of(context).formatTemperature(
                                  temperature.toDouble(),
                                  decimals: 1)),
                      const SizedBox(height: 14),
                      _row(Icons.water_drop_outlined, 'Humidity', '—'),
                      const SizedBox(height: 14),
                      _row(Icons.people_outline, 'Occupancy', '—'),
                      const SizedBox(height: 16),
                      if (sensor != null)
                        Text(sensor.name,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      const Text('— No sensor reading',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
              )));
        },
      );

  Widget _row(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 20, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey))),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}
