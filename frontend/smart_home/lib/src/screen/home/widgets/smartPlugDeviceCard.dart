import 'package:flutter/material.dart';

class SmartPlugDeviceCard extends StatelessWidget {
  const SmartPlugDeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isOn,
    this.onPowerChanged,
  });

  final String title;
  final String subtitle;
  final bool isOn;
  final ValueChanged<bool>? onPowerChanged;

  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: Icon(Icons.power,
            size: 28,
            color: isOn ? Theme.of(context).colorScheme.primary : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: isOn, onChanged: onPowerChanged),
      ));
}
