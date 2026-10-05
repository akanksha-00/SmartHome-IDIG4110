import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/automation_data.dart';
import 'package:smart_home/src/models/automations/automation_model.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';

class AutomationDialog extends StatefulWidget {
  const AutomationDialog({
    super.key,
    required this.devices,
    this.automation,
    this.initialRoomId = 'living',
  });

  final List<SmartDeviceModel> devices;
  final AutomationModel? automation;
  final String initialRoomId;

  @override
  State<AutomationDialog> createState() => _AutomationDialogState();
}

class _AutomationDialogState extends State<AutomationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _temperatureController;
  late String _roomId;
  late AutomationTriggerType _triggerType;
  late AutomationRepeat _repeat;
  late AutomationActionType _actionType;
  late TimeOfDay _time;
  late bool _isEnabled;
  late Set<String> _selectedDevices;
  double _brightness = 80;
  int _speed = 2;
  String? _deviceError;

  @override
  void initState() {
    super.initState();
    final routine = widget.automation;
    final trigger = routine?.trigger;
    final action = routine?.action;
    _nameController = TextEditingController(text: routine?.title ?? '');
    _temperatureController =
        TextEditingController(text: '${trigger?.temperatureC ?? 26}');
    _roomId = routine?.roomId ?? widget.initialRoomId;
    _triggerType = trigger?.type ?? AutomationTriggerType.schedule;
    _repeat = trigger?.repeat ?? AutomationRepeat.daily;
    _actionType = action?.type ?? AutomationActionType.turnOn;
    final minutes = trigger?.minutesOfDay ?? 420;
    _time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    _isEnabled = routine?.isEnabled ?? true;
    _selectedDevices = action?.deviceIds.toSet() ?? {};
    if (action?.type == AutomationActionType.brightness) {
      _brightness = action!.level.toDouble();
    }
    if (action?.type == AutomationActionType.fanSpeed) {
      _speed = action!.level;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  List<SmartDeviceModel> get _eligibleDevices => widget.devices.where((device) {
        if (device.roomId != _roomId) return false;
        return switch (_actionType) {
          AutomationActionType.brightness => device is LightDeviceModel,
          AutomationActionType.fanSpeed => device is FanDeviceModel,
          _ => true,
        };
      }).toList();

  void _keepEligibleSelection() {
    final eligibleIds = _eligibleDevices.map((device) => device.id).toSet();
    _selectedDevices.retainAll(eligibleIds);
    _deviceError = null;
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (!mounted || time == null) return;
    setState(() => _time = time);
  }

  void _save() {
    final valid = _formKey.currentState!.validate();
    _keepEligibleSelection();
    if (_selectedDevices.isEmpty) {
      setState(() => _deviceError = 'Choose at least one device');
      return;
    }
    if (!valid) return;
    Navigator.of(context).pop(AutomationModel(
      id: widget.automation?.id ??
          'automation-${DateTime.now().microsecondsSinceEpoch}',
      title: _nameController.text.trim(),
      floorId: widget.automation?.floorId ?? 'floor1',
      roomId: _roomId,
      isEnabled: _isEnabled,
      trigger: AutomationTrigger(
        type: _triggerType,
        minutesOfDay: _time.hour * 60 + _time.minute,
        repeat: _repeat,
        temperatureC: _triggerType == AutomationTriggerType.temperature
            ? double.parse(_temperatureController.text.trim())
            : 26,
      ),
      action: AutomationAction(
        type: _actionType,
        deviceIds: _selectedDevices.toList(),
        level: _actionType == AutomationActionType.fanSpeed
            ? _speed
            : _brightness.round(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final devices = _eligibleDevices;
    return AlertDialog(
      title: Text(
          widget.automation == null ? 'Add automation' : 'Edit automation'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('automation-name'),
                  controller: _nameController,
                  maxLength: 80,
                  decoration:
                      const InputDecoration(labelText: 'Automation name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an automation name'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('automation-room'),
                  initialValue: _roomId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Room'),
                  items: automationRoomLabels.entries
                      .map((room) => DropdownMenuItem(
                            value: room.key,
                            child: Text(room.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _roomId = value;
                      _keepEligibleSelection();
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text('WHEN',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<AutomationTriggerType>(
                  key: const ValueKey('automation-trigger'),
                  initialValue: _triggerType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Trigger'),
                  items: const [
                    DropdownMenuItem(
                        value: AutomationTriggerType.schedule,
                        child: Text('At a scheduled time')),
                    DropdownMenuItem(
                        value: AutomationTriggerType.sunset,
                        child: Text('At sunset')),
                    DropdownMenuItem(
                        value: AutomationTriggerType.temperature,
                        child: Text('Temperature rises above')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _triggerType = value);
                  },
                ),
                const SizedBox(height: 16),
                if (_triggerType == AutomationTriggerType.temperature)
                  TextFormField(
                    key: const ValueKey('automation-temperature'),
                    controller: _temperatureController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                        labelText: 'Temperature threshold', suffixText: '°C'),
                    validator: (value) {
                      final temperature = double.tryParse(value?.trim() ?? '');
                      if (temperature == null ||
                          !temperature.isFinite ||
                          temperature < -50 ||
                          temperature > 60) {
                        return 'Enter a temperature between −50 and 60°C';
                      }
                      return null;
                    },
                  )
                else ...[
                  if (_triggerType == AutomationTriggerType.schedule) ...[
                    OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<AutomationRepeat>(
                    initialValue: _repeat,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: const [
                      DropdownMenuItem(
                          value: AutomationRepeat.daily, child: Text('Daily')),
                      DropdownMenuItem(
                          value: AutomationRepeat.weekdays,
                          child: Text('Weekdays')),
                      DropdownMenuItem(
                          value: AutomationRepeat.weekends,
                          child: Text('Weekends')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _repeat = value);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                const Text('THEN',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<AutomationActionType>(
                  key: const ValueKey('automation-action'),
                  initialValue: _actionType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(
                        value: AutomationActionType.turnOn,
                        child: Text('Turn on')),
                    DropdownMenuItem(
                        value: AutomationActionType.turnOff,
                        child: Text('Turn off')),
                    DropdownMenuItem(
                        value: AutomationActionType.brightness,
                        child: Text('Set light brightness')),
                    DropdownMenuItem(
                        value: AutomationActionType.fanSpeed,
                        child: Text('Set fan speed')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _actionType = value;
                      _keepEligibleSelection();
                    });
                  },
                ),
                if (_actionType == AutomationActionType.brightness) ...[
                  const SizedBox(height: 16),
                  Text('Brightness: ${_brightness.round()}%'),
                  Slider(
                      value: _brightness,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${_brightness.round()}%',
                      onChanged: (value) =>
                          setState(() => _brightness = value)),
                ],
                if (_actionType == AutomationActionType.fanSpeed) ...[
                  const SizedBox(height: 16),
                  const Text('Fan speed'),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {_speed},
                    onSelectionChanged: (value) =>
                        setState(() => _speed = value.first),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('Devices',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'No compatible devices in this room. Choose another room or action.'),
                  ),
                for (final device in devices)
                  CheckboxListTile(
                    key: ValueKey('automation-target-${device.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(device.title),
                    subtitle: Text(device.subtitle),
                    value: _selectedDevices.contains(device.id),
                    onChanged: (value) => setState(() {
                      value == true
                          ? _selectedDevices.add(device.id)
                          : _selectedDevices.remove(device.id);
                      _deviceError = null;
                    }),
                  ),
                if (_deviceError != null)
                  Text(_deviceError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable automation'),
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('automation-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
