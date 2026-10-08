import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/devices/device_create_request.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog(
      {super.key, required this.roomId, required this.roomName});
  final String roomId;
  final String roomName;

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController(
    text: 'device-${DateTime.now().microsecondsSinceEpoch}',
  );
  final _formKey = GlobalKey<FormState>();
  String _deviceType = 'light';
  String? _submittedId;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  DeviceCreateRequest _createRequest() => DeviceCreateRequest(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        type: _deviceType,
        roomId: widget.roomId,
        capabilities: {
          'power': const DeviceCapability(type: 'boolean'),
          if (_deviceType == 'light')
            'brightness':
                const DeviceCapability(type: 'integer', min: 0, max: 100),
          if (_deviceType == 'fan')
            'speed': const DeviceCapability(type: 'integer', min: 1, max: 3),
        },
        state: {
          'power': false,
          if (_deviceType == 'light') 'brightness': 100,
          if (_deviceType == 'fan') 'speed': 1,
        },
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<DeviceBloc, DeviceState>(
        listenWhen: (previous, current) =>
            previous.isAdding && !current.isAdding,
        listener: (context, state) {
          if (_submittedId != null && state.lastAddedDeviceId == _submittedId) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) => PopScope(
          canPop: !state.isAdding,
          child: AlertDialog(
            title: Text('Add device to ${widget.roomName}'),
            content: SingleChildScrollView(
                child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownMenu<String>(
                    label: const Text('Add device'),
                    initialSelection: _deviceType,
                    enabled: !state.isAdding,
                    selectOnly: true,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 'light', label: 'Light'),
                      DropdownMenuEntry(value: 'fan', label: 'Fan'),
                      DropdownMenuEntry(value: 'smart_plug', label: 'Plug'),
                    ],
                    onSelected: (value) {
                      if (value != null) _deviceType = value;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('add-device-name'),
                    controller: _nameController,
                    enabled: !state.isAdding,
                    decoration: const InputDecoration(labelText: 'Device name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a device name'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('add-device-id'),
                    controller: _idController,
                    enabled: !state.isAdding,
                    decoration: const InputDecoration(labelText: 'Device ID'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a device ID'
                        : null,
                  ),
                  if (_submittedId != null && state.addError != null) ...[
                    const SizedBox(height: 18),
                    Text('Could not add device: ${state.addError}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            )),
            actions: [
              TextButton(
                onPressed:
                    state.isAdding ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: state.isAdding
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        final request = _createRequest();
                        _submittedId = request.id;
                        context
                            .read<DeviceBloc>()
                            .add(DeviceAddRequested(request));
                      },
                child: Text(state.isAdding ? 'Adding…' : 'Add'),
              ),
            ],
          ),
        ),
      );
}
