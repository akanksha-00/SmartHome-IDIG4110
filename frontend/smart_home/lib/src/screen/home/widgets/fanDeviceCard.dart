import 'package:flutter/material.dart';

class FanDeviceCard extends StatelessWidget {
  const FanDeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isOn,
    required this.speed,
    this.speedValues = const [1, 2, 3],
    this.onPowerChanged,
    this.onSpeedChanged,
  });

  final String title;
  final String subtitle;
  final bool isOn;
  final int speed;
  final List<int> speedValues;
  final ValueChanged<bool>? onPowerChanged;
  final ValueChanged<int>? onSpeedChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.air,
                size: 28,
                color:
                    isOn ? Theme.of(context).colorScheme.primary : Colors.grey),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Switch(value: isOn, onChanged: onPowerChanged),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: speedValues.isEmpty
                ? Text('Speed: $speed')
                : SegmentedButton<int>(
                    segments: [
                      for (final value in speedValues)
                        ButtonSegment(value: value, label: Text('$value')),
                    ],
                    selected: speedValues.contains(speed) ? {speed} : {},
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    onSelectionChanged: isOn && onSpeedChanged != null
                        ? (selection) {
                            if (selection.isNotEmpty) {
                              onSpeedChanged!(selection.first);
                            }
                          }
                        : null,
                  ),
          ),
        ]),
      );
}
