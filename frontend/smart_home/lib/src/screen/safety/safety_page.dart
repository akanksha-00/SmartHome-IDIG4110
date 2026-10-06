import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/safety_controller.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/models/safety/safety_model.dart';
import 'package:smart_home/src/screen/safety/widgets/safety_device_dialog.dart';
import 'package:smart_home/src/screen/safety/widgets/safety_device_tile.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key, this.controller});
  final SafetyController? controller;

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  late final SafetyController _controller;
  final _searchController = TextEditingController();
  String _query = '';
  String _floor = 'all';
  String _room = 'all';
  bool _showAllContacts = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        SafetyController(
            devices: sampleSafetyDevices, events: sampleSafetyEvents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  List<SafetyDevice> get _filteredDevices {
    final query = _query.trim().toLowerCase();
    return _controller.devices
        .where((device) =>
            (_floor == 'all' || device.floorId == _floor) &&
            (_room == 'all' || device.roomId == _room) &&
            '${device.title} ${device.location} ${safetyRoomLabels[device.roomId]} '
                    '${safetyDeviceTypeLabels[device.type]}'
                .toLowerCase()
                .contains(query))
        .toList();
  }

  List<SafetyEvent> get _filteredEvents => _controller.events
      .where((event) =>
          (_floor == 'all' ||
              event.floorId == null ||
              event.floorId == _floor) &&
          (_room == 'all' || event.roomId == null || event.roomId == _room))
      .toList();

  Future<void> _editDevice([SafetyDevice? device]) async {
    final result = await showDialog<SafetyDevice>(
        context: context,
        builder: (context) => SafetyDeviceDialog(
              device: device,
              initialRoomId: _room == 'all' ? 'living' : _room,
            ));
    if (!mounted || result == null) return;
    setState(() {
      _query = '';
      _searchController.clear();
      if (_room != 'all') _room = result.roomId;
      _showAllContacts = true;
    });
    _controller.saveDevice(result);
  }

  Future<void> _removeDevice(SafetyDevice device) async {
    final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remove device?'),
              content: Text(
                  'Remove “${device.title}” from Safety? Its event history will be kept.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Remove')),
              ],
            ));
    if (!mounted || remove != true) return;
    _controller.removeDevice(device.id);
  }

  void _showDevice(SafetyDevice device) => showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final events = _controller.events
            .where((event) => event.deviceId == device.id)
            .take(3)
            .toList();
        return AlertDialog(
          title: Text(device.title),
          content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafetyStateBadge(device: device),
                  const SizedBox(height: 16),
                  _detailLine('Type', safetyDeviceTypeLabels[device.type]!),
                  _detailLine('Floor',
                      safetyFloorLabels[device.floorId] ?? device.floorId),
                  _detailLine(
                      'Room', safetyRoomLabels[device.roomId] ?? device.roomId),
                  _detailLine('Location', device.location),
                  _detailLine(
                      'Connection',
                      device.isOnline
                          ? 'Online'
                          : 'Offline · Awaiting connection'),
                  _detailLine(
                      'Battery',
                      device.batteryPercent == null
                          ? 'Not reported'
                          : '${device.batteryPercent}%'),
                  if (device.isOnline && device.temperatureC != null)
                    _detailLine('Temperature', '${device.temperatureC}°C'),
                  if (device.isOnline && device.isLocked != null)
                    _detailLine(
                        'Lock', device.isLocked! ? 'Locked' : 'Unlocked'),
                  const SizedBox(height: 20),
                  const Text('Recent activity',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (events.isEmpty) const Text('No events recorded'),
                  for (final event in events) ...[
                    Text(event.title),
                    Text(event.timeLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ],
                ],
              ))),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _removeDevice(device);
                },
                child: const Text('Remove')),
            OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _editDevice(device);
                },
                child: const Text('Edit')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close')),
          ],
        );
      });

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value)),
        ]),
      );

  void _requestMode(AlarmMode mode) {
    if (_controller.setMode(mode)) return;
    final issues = _controller.armingIssues(mode);
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Review devices before arming'),
              content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final issue in issues)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(issue))
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'))
              ],
            ));
  }

  Widget _buildHeader() => LayoutBuilder(builder: (context, constraints) {
        const title = Text('Safety',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        final add = OutlinedButton.icon(
          key: const ValueKey('safety-add-device'),
          onPressed: () => _editDevice(),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.add),
          label: const Text('Add device'),
        );
        if (constraints.maxWidth < 420) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: add),
              ]);
        }
        return Row(children: [
          const Expanded(child: title),
          const SizedBox(width: 16),
          add
        ]);
      });

  Widget _overviewStatus(
          {required IconData icon,
          required String title,
          required String subtitle,
          Color? color}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
        ],
      );

  Widget _buildOverview() {
    final colors = Theme.of(context).colorScheme;
    final sensors =
        _controller.devices.where((device) => device.isSafetySensor).toList();
    final reporting = sensors
        .where((device) =>
            device.isOnline && device.state != SafetyDeviceState.unknown)
        .length;
    final alarm = sensors.any((device) => device.isAlert);
    final complete = sensors.isNotEmpty && reporting == sensors.length;
    final modeLabel = switch (_controller.mode) {
      AlarmMode.disarmed => 'Disarmed',
      AlarmMode.home => 'Armed home',
      AlarmMode.away => 'Armed away',
    };
    final statusColor = complete && !alarm
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade700)
        : colors.primary;
    final issues = _controller.attentionDevices;
    return Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, constraints) {
            final intrusion = _overviewStatus(
              icon: Icons.shield_outlined,
              title: 'Intrusion: $modeLabel',
              subtitle: switch (_controller.mode) {
                AlarmMode.disarmed => 'Intrusion alarm is off',
                AlarmMode.home => 'Doors and windows monitored',
                AlarmMode.away => 'Doors, windows and motion monitored',
              },
            );
            final safety = _overviewStatus(
              icon: Icons.sensors_outlined,
              title: alarm
                  ? 'Safety alert detected'
                  : complete
                      ? 'Safety monitoring active'
                      : 'Safety monitoring incomplete',
              subtitle:
                  '$reporting of ${sensors.length} safety sensors reporting',
              color: statusColor,
            );
            final buttons = Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(
                key: const ValueKey('arm-home'),
                onPressed: () => _requestMode(AlarmMode.home),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Arm home'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              FilledButton.icon(
                key: const ValueKey('arm-away'),
                onPressed: () => _requestMode(AlarmMode.away),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Arm away'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              if (_controller.mode != AlarmMode.disarmed)
                TextButton.icon(
                    key: const ValueKey('disarm'),
                    onPressed: () => _requestMode(AlarmMode.disarmed),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Disarm')),
            ]);
            if (constraints.maxWidth >= 1100) {
              return Row(children: [
                Expanded(child: intrusion),
                const SizedBox(width: 24),
                Expanded(child: safety),
                const SizedBox(width: 24),
                SizedBox(width: 310, child: buttons),
              ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxWidth >= 640)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: intrusion),
                          const SizedBox(width: 24),
                          Expanded(child: safety),
                        ])
                  else ...[intrusion, const SizedBox(height: 20), safety],
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerRight, child: buttons),
                ]);
          })),
      if (issues.isNotEmpty) ...[
        const Divider(height: 1),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline, color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${issues.first.attentionMessage}${issues.length > 1 ? ' · ${issues.length - 1} more' : ''}',
                        style: TextStyle(color: colors.primary)),
                    TextButton(
                      key: const ValueKey('safety-review'),
                      onPressed: () => _showDevice(issues.first),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Review'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 16)
                          ]),
                    ),
                  ])),
            ])),
      ],
    ]));
  }

  Widget _buildFilters() => LayoutBuilder(builder: (context, constraints) {
        final width = math.min(150.0, constraints.maxWidth);
        const decoration = InputDecorationTheme(
          constraints: BoxConstraints.tightFor(height: 48),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
        );
        final search = SizedBox(
            height: 48,
            child: TextField(
              key: const ValueKey('safety-search'),
              controller: _searchController,
              decoration: InputDecoration(
                  hintText: 'Search sensors',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: const OutlineInputBorder(),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                                _query = '';
                                _searchController.clear();
                              }))),
              onChanged: (value) => setState(() => _query = value),
            ));
        final floors = DropdownMenu<String>(
          key: const ValueKey('safety-floor-filter'),
          width: width,
          initialSelection: _floor,
          selectOnly: true,
          inputDecorationTheme: decoration,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: 'all', label: 'All floors'),
            ...safetyFloorLabels.entries.map((entry) =>
                DropdownMenuEntry(value: entry.key, label: entry.value)),
          ],
          onSelected: (value) {
            if (value != null) {
              setState(() {
                _floor = value;
                _room = 'all';
              });
            }
          },
        );
        final rooms = DropdownMenu<String>(
          key: ValueKey('safety-room-filter-$_floor-$_room'),
          width: width,
          initialSelection: _room,
          selectOnly: true,
          inputDecorationTheme: decoration,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: 'all', label: 'All rooms'),
            ...safetyRoomLabels.entries.map((entry) =>
                DropdownMenuEntry(value: entry.key, label: entry.value)),
          ],
          onSelected: (value) {
            if (value != null) setState(() => _room = value);
          },
        );
        if (constraints.maxWidth >= 600) {
          return Row(children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            floors,
            const SizedBox(width: 12),
            rooms
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [floors, rooms]),
            ]);
      });

  Widget _buildDeviceGroup(List<SafetyDevice> devices, {required bool safety}) {
    final open = devices
        .where((device) =>
            device.isOnline &&
            device.isContact &&
            device.state == SafetyDeviceState.open)
        .length;
    final reporting = devices
        .where((device) =>
            device.isOnline && device.state != SafetyDeviceState.unknown)
        .length;
    final shown =
        !safety && !_showAllContacts ? devices.take(3).toList() : devices;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                      safety
                          ? Icons.local_fire_department_outlined
                          : Icons.door_front_door_outlined,
                      size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            safety
                                ? 'Safety sensors'
                                : 'Doors, windows & motion',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            safety
                                ? '${devices.length} devices · $reporting reporting'
                                : '${devices.length} devices · $open open',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ])),
                ]),
                if (safety) ...[const SizedBox(height: 16), _buildFilters()],
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child:
                          Center(child: Text('No devices match your filters'))),
                for (var index = 0; index < shown.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  SafetyDeviceTile(
                      key: ValueKey('safety-device-${shown[index].id}'),
                      device: shown[index],
                      onTap: () => _showDevice(shown[index])),
                ],
                if (!safety && devices.length > 3) ...[
                  const SizedBox(height: 8),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('safety-view-all'),
                        onPressed: () => setState(
                            () => _showAllContacts = !_showAllContacts),
                        icon: Icon(_showAllContacts
                            ? Icons.expand_less
                            : Icons.arrow_forward),
                        label: Text(_showAllContacts
                            ? 'Show fewer devices'
                            : 'View all ${devices.length} devices'),
                      )),
                ],
              ],
            )));
  }

  void _showEvent(SafetyEvent event) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(event.title),
            content: SizedBox(
                width: 440,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.timeLabel),
                      const SizedBox(height: 8),
                      if (event.roomId != null) ...[
                        Text(safetyRoomLabels[event.roomId] ?? event.roomId!),
                        const SizedBox(height: 12)
                      ],
                      Text(event.description),
                    ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'))
            ],
          ));

  Widget _eventTile(SafetyEvent event) => ListTile(
        key: ValueKey('safety-event-${event.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(safetyDeviceIcon(event.type),
            color: Theme.of(context).colorScheme.primary),
        title: Text(event.title),
        subtitle: Text(
            '${event.timeLabel}${event.roomId == null ? '' : ' · ${safetyRoomLabels[event.roomId] ?? event.roomId}'}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showEvent(event),
      );

  void _showHistory() {
    final events = _filteredEvents;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Event history'),
              content: SizedBox(
                  width: 520,
                  height: math.min(450, MediaQuery.sizeOf(context).height * .6),
                  child: events.isEmpty
                      ? const Center(child: Text('No events in this selection'))
                      : ListView.separated(
                          itemCount: events.length,
                          itemBuilder: (context, index) =>
                              _eventTile(events[index]),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                        )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'))
              ],
            ));
  }

  Widget _buildRecentEvents() {
    final events = _filteredEvents.take(4).toList();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Recent events',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                if (events.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No events in this selection')),
                for (final event in events) ...[
                  _eventTile(event),
                  const Divider(height: 1)
                ],
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _showHistory,
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('View history'),
                          Icon(Icons.arrow_forward, size: 18)
                        ])),
              ],
            )));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final devices = _filteredDevices;
          final safety =
              devices.where((device) => device.isSafetySensor).toList();
          final intrusion =
              devices.where((device) => !device.isSafetySensor).toList();
          final groups =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildDeviceGroup(safety, safety: true),
            const SizedBox(height: 12),
            _buildDeviceGroup(intrusion, safety: false),
          ]);
          return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildOverview(),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 1000) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            groups,
                            const SizedBox(height: 16),
                            _buildRecentEvents()
                          ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: groups),
                          const SizedBox(width: 16),
                          SizedBox(width: 340, child: _buildRecentEvents()),
                        ]);
                  }),
                ],
              ));
        },
      );
}
