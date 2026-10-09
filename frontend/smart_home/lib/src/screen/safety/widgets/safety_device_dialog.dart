import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';

class SafetyDeviceDialog extends StatefulWidget {
  const SafetyDeviceDialog(
      {super.key, this.device, this.initialRoomId = 'living'});
  final SafetyDevice? device;
  final String initialRoomId;

  @override
  State<SafetyDeviceDialog> createState() => _SafetyDeviceDialogState();
}

class _SafetyDeviceDialogState extends State<SafetyDeviceDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late SafetyDeviceType _type;
  late String _room;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.device?.title ?? '');
    _location = TextEditingController(text: widget.device?.location ?? '');
    _type = widget.device?.type ?? SafetyDeviceType.smoke;
    _room = widget.device?.roomId ?? widget.initialRoomId;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final device = widget.device?.withDetails(
          title: _name.text.trim(),
          roomId: _room,
          location: _location.text.trim(),
        ) ??
        SafetyDevice(
          id: 'safety-${DateTime.now().microsecondsSinceEpoch}',
          title: _name.text.trim(),
          type: _type,
          floorId: 'floor1',
          roomId: _room,
          location: _location.text.trim(),
        );
    Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.device == null ? 'Add safety device' : 'Edit device'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<SafetyDeviceType>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Device type'),
                      items: safetyDeviceTypeLabels.entries
                          .map((entry) => DropdownMenuItem(
                              value: entry.key, child: Text(entry.value)))
                          .toList(),
                      onChanged: widget.device != null
                          ? null
                          : (value) {
                              if (value != null) setState(() => _type = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('safety-device-name'),
                      controller: _name,
                      maxLength: 80,
                      decoration:
                          const InputDecoration(labelText: 'Device name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a device name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _room,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Room'),
                      items: safetyRoomLabels.entries
                          .map((entry) => DropdownMenuItem(
                              value: entry.key, child: Text(entry.value)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _room = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('safety-device-location'),
                      controller: _location,
                      maxLength: 100,
                      decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'For example, above the counter'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a location'
                              : null,
                    ),
                  ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              key: const ValueKey('safety-device-save'),
              onPressed: _save,
              child: const Text('Save')),
        ],
      );
}
