import 'package:flutter/material.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartPlugDeviceModel.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  String _deviceType = 'Light';

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
        ),
      'Fan' => FanDeviceModel(
          id: id,
          title: title,
          subtitle: subtitle,
        ),
      'Plug' => SmartPlugDeviceModel(
          id: id,
          title: title,
          subtitle: subtitle,
        ),
      _ => throw StateError('unknown device type')
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Device',
      ),
      content: Form(
        key: _formkey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownMenu<String>(
              label: const Text('Device Type'),
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
