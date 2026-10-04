import 'package:flutter/material.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartPlugDeviceModel.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  String _deviceType = 'Light';

  String get _roomName => switch (widget.roomId) {
        'living' => 'Living Room',
        'kitchen' => 'Kitchen',
        'bedroom1' => 'Bedroom 1',
        'bathroom1' => 'Bathroom 1',
        _ => 'Room',
      };

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  SmartDeviceModel _createDevice() {
    final id = 'device-${DateTime.now().microsecondsSinceEpoch}';
    final title = _nameController.text.trim();
    final subtitle = _locationController.text.trim();

    return switch (_deviceType) {
      'Light' => LightDeviceModel(
          id: id,
          title: title,
          subtitle: subtitle,
          roomId: widget.roomId,
        ),
      'Fan' => FanDeviceModel(
          id: id,
          title: title,
          subtitle: subtitle,
          roomId: widget.roomId,
        ),
      'Plug' => SmartPlugDeviceModel(
          id: id,
          title: title,
          subtitle: subtitle,
          roomId: widget.roomId,
        ),
      _ => throw StateError('unknown device type')
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add device to $_roomName'),
      content: Form(
        key: _formkey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownMenu<String>(
              label: const Text('Add device'),
              initialSelection: _deviceType,
              selectOnly: true,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'Light', label: 'Light'),
                DropdownMenuEntry(value: 'Fan', label: 'Fan'),
                DropdownMenuEntry(value: 'Plug', label: 'Plug'),
              ],
              onSelected: (value) {
                if (value != null) {
                  _deviceType = value;
                }
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a device name';
                }
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Device location',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a device location';
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: () {
            if (!_formkey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(_createDevice());
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
