import 'package:flutter/material.dart';

class SmartPlugDeviceCard extends StatefulWidget {
  const SmartPlugDeviceCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.initialIsOn,
      this.onPowerChanged});

  final String title;
  final String subtitle;
  final bool initialIsOn;
  final ValueChanged<bool>? onPowerChanged;

  @override
  State<SmartPlugDeviceCard> createState() => _SmartPlugDeviceCardState();
}

class _SmartPlugDeviceCardState extends State<SmartPlugDeviceCard> {
  late bool _isPlugOn;

  @override
  void initState() {
    super.initState();
    _isPlugOn = widget.initialIsOn;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        child: ListTile(
      leading: Icon(
        Icons.power,
        size: 28,
        color: _isPlugOn ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: Switch(
          value: _isPlugOn,
          onChanged: (value) {
            setState(() {
              _isPlugOn = value;
            });
            widget.onPowerChanged?.call(value);
          }),
    ));
  }
}
