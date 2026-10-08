import 'package:flutter/material.dart';

class LightDeviceCard extends StatefulWidget {
  const LightDeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isOn,
    required this.brightness,
    this.onPowerChanged,
    this.onBrightnessChanged,
  });

  final String title;
  final String subtitle;
  final bool isOn;
  final double brightness;
  final ValueChanged<bool>? onPowerChanged;
  final ValueChanged<double>? onBrightnessChanged;

  @override
  State<LightDeviceCard> createState() => _LightDeviceCardState();
}

class _LightDeviceCardState extends State<LightDeviceCard> {
  // Only the unfinished drag is local. Committed values come from DeviceBloc.
  double? _dragBrightness;

  @override
  void didUpdateWidget(covariant LightDeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOn || widget.onBrightnessChanged == null) {
      _dragBrightness = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _dragBrightness ?? widget.brightness;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.lightbulb,
                color: widget.isOn ? Colors.amber : Colors.grey, size: 28),
            title: Text(widget.title),
            subtitle: Text(widget.subtitle),
            trailing:
                Switch(value: widget.isOn, onChanged: widget.onPowerChanged),
          ),
          Row(children: [
            Expanded(
                child: Slider(
              value: brightness.clamp(0.0, 1.0),
              onChanged: widget.isOn && widget.onBrightnessChanged != null
                  ? (value) => setState(() => _dragBrightness = value)
                  : null,
              // A drag sends one PATCH, avoiding a request for every pixel.
              onChangeEnd: widget.isOn && widget.onBrightnessChanged != null
                  ? (value) {
                      setState(() => _dragBrightness = null);
                      widget.onBrightnessChanged!(value);
                    }
                  : null,
            )),
            SizedBox(
                width: 48,
                child: Text(
                    widget.isOn ? '${(brightness * 100).round()}%' : 'Off')),
          ]),
        ],
      ),
    );
  }
}
