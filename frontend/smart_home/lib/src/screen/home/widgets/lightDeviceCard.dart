import 'package:flutter/material.dart';

class LightDeviceCard extends StatefulWidget {
  const LightDeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initialIsOn,
    required this.initialValue,
  });

  final String title;
  final String subtitle;
  final bool initialIsOn;
  final double initialValue;

  @override
  State<LightDeviceCard> createState() => _LightDeviceCardState();
}

class _LightDeviceCardState extends State<LightDeviceCard> {
  late bool _isLightOn;
  late double _brightness;

  @override
  void initState() {
    super.initState();
    _isLightOn = widget.initialIsOn;
    _brightness = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.lightbulb,
              color: _isLightOn ? Colors.amber : Colors.grey,
              size: 28,
            ),
            title: Text(widget.title),
            subtitle: Text(widget.subtitle),
            trailing: Switch(
              value: _isLightOn,
              onChanged: (value) {
                setState(() {
                  _isLightOn = value;
                });
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _brightness,
                  onChanged: _isLightOn
                      ? (value) {
                          setState(() {
                            _brightness = value;
                          });
                        }
                      : null,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  _isLightOn ? '${(_brightness * 100).round()}%' : 'Off',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
