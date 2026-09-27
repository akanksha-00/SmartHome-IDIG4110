import 'package:flutter/material.dart';

class FanDeviceCard extends StatefulWidget {
  const FanDeviceCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.initialIsOn,
      required this.speed,
      this.onPowerChanged,
      this.onSpeedChanged});

  final String title;
  final String subtitle;
  final bool initialIsOn;
  final int speed;
  final ValueChanged<bool>? onPowerChanged;
  final ValueChanged<int>? onSpeedChanged;

  @override
  State<FanDeviceCard> createState() => _FanDeviceCardState();
}

class _FanDeviceCardState extends State<FanDeviceCard> {
  late bool _isFanOn;
  late int _speed;

  @override
  void initState() {
    super.initState();
    _isFanOn = widget.initialIsOn;
    _speed = widget.speed;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.air,
              size: 28,
              color: _isFanOn
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            title: Text(widget.title),
            subtitle: Text(widget.subtitle),
            trailing: Switch(
              value: _isFanOn,
              onChanged: (value) {
                setState(() {
                  _isFanOn = value;
                });
                widget.onPowerChanged?.call(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text('1'),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('2'),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('3'),
                ),
              ],
              selected: {_speed},
              showSelectedIcon: false,
              onSelectionChanged: _isFanOn
                  ? (selection) {
                      setState(() {
                        _speed = selection.first;
                      });
                      widget.onSpeedChanged?.call(selection.first);
                    }
                  : null,
            ),
          )
        ],
      ),
    );
  }
}
