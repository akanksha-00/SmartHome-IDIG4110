import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/dummyData/automation_data.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/automations/automation_model.dart';
import 'package:smart_home/src/screen/automations/widgets/automation_dialog.dart';

class AutomationsPage extends StatefulWidget {
  const AutomationsPage({super.key});

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends State<AutomationsPage> {
  final _automations = createSampleAutomations();
  final _devices = createSmartDevices();
  final _searchController = TextEditingController();
  String _search = '';
  String _floorId = 'all';
  String _roomId = 'all';
  String _status = 'All';

  late final _deviceTitles = {
    for (final device in _devices) device.id: device.title
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _triggerDescription(AutomationTrigger trigger) => trigger.type ==
          AutomationTriggerType.temperature
      ? 'Temperature rises above ${AppSettingsScope.of(context).formatTemperature(trigger.temperatureC)}'
      : trigger.description;

  List<AutomationModel> get _matchingAutomations {
    final query = _search.trim().toLowerCase();
    return _automations.where((routine) {
      return (_floorId == 'all' || routine.floorId == _floorId) &&
          (_roomId == 'all' || routine.roomId == _roomId) &&
          ('${routine.title} ${_triggerDescription(routine.trigger)} '
                  '${routine.action.describe(_deviceTitles)} '
                  '${automationRoomLabels[routine.roomId]}')
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  List<AutomationRun> get _matchingRuns => sampleAutomationRuns
      .where((run) =>
          (_floorId == 'all' || run.floorId == _floorId) &&
          (_roomId == 'all' || run.roomId == _roomId))
      .toList();

  Future<void> _openEditor([AutomationModel? routine]) async {
    final result = await showDialog<AutomationModel>(
      context: context,
      builder: (context) => AutomationDialog(
        devices: _devices,
        automation: routine,
        initialRoomId: _roomId == 'all' ? 'living' : _roomId,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final index = _automations.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        _automations.add(result);
      } else {
        _automations[index] = result;
      }
      // Show the saved routine even if the previous filters excluded it.
      _search = '';
      _searchController.clear();
      _status = 'All';
      if (_roomId != 'all') _roomId = result.roomId;
    });
  }

  void _setEnabled(AutomationModel routine, bool enabled) => setState(() {
        final index = _automations.indexWhere((item) => item.id == routine.id);
        if (index >= 0) _automations[index] = routine.withEnabled(enabled);
      });

  Future<void> _deleteRoutine(AutomationModel routine) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete automation?'),
        content:
            Text('Remove “${routine.title}”? Its run history will be kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || remove != true) return;
    setState(() => _automations.removeWhere((item) => item.id == routine.id));
  }

  IconData _triggerIcon(AutomationTriggerType type, {int minutes = 420}) =>
      switch (type) {
        AutomationTriggerType.temperature => Icons.thermostat_outlined,
        AutomationTriggerType.sunset => Icons.nights_stay_outlined,
        AutomationTriggerType.schedule => minutes >= 22 * 60
            ? Icons.bedtime_outlined
            : minutes >= 18 * 60
                ? Icons.nights_stay_outlined
                : Icons.light_mode_outlined,
      };

  IconData _roomIcon(String room) => switch (room) {
        'kitchen' => Icons.kitchen_outlined,
        'bedroom1' => Icons.bed_outlined,
        'bathroom1' => Icons.bathtub_outlined,
        _ => Icons.weekend_outlined,
      };

  Widget _buildHeader() => LayoutBuilder(builder: (context, constraints) {
        const title = Text('Automations',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        final add = FilledButton.icon(
          key: const ValueKey('add-automation'),
          onPressed: () => _openEditor(),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add automation'),
        );
        if (constraints.maxWidth < 500) {
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

  Widget _buildSearch() => SizedBox(
        height: 48,
        child: TextField(
          key: const ValueKey('automation-search'),
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search automations',
            prefixIcon: const Icon(Icons.search),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _search = '';
                      _searchController.clear();
                    }),
                  ),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
      );

  Widget _buildFilters() => LayoutBuilder(builder: (context, constraints) {
        final width = math.min(200.0, constraints.maxWidth);
        const decoration = InputDecorationTheme(
          constraints: BoxConstraints.tightFor(height: 48),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
        );
        final floors = DropdownMenu<String>(
          key: const ValueKey('automation-floor-filter'),
          width: width,
          initialSelection: _floorId,
          selectOnly: true,
          inputDecorationTheme: decoration,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: 'all', label: 'All floors'),
            ...automationFloorLabels.entries.map((entry) =>
                DropdownMenuEntry(value: entry.key, label: entry.value)),
          ],
          onSelected: (value) {
            if (value == null) return;
            setState(() {
              _floorId = value;
              _roomId = 'all';
            });
          },
        );
        final rooms = DropdownMenu<String>(
          key: ValueKey('automation-room-filter-$_floorId-$_roomId'),
          width: width,
          initialSelection: _roomId,
          selectOnly: true,
          inputDecorationTheme: decoration,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: 'all', label: 'All rooms'),
            ...automationRoomLabels.entries.map((entry) =>
                DropdownMenuEntry(value: entry.key, label: entry.value)),
          ],
          onSelected: (value) {
            if (value != null) setState(() => _roomId = value);
          },
        );
        if (constraints.maxWidth >= 700) {
          return Row(children: [
            Expanded(child: _buildSearch()),
            const SizedBox(width: 16),
            floors,
            const SizedBox(width: 16),
            rooms,
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearch(),
              const SizedBox(height: 16),
              Wrap(spacing: 16, runSpacing: 16, children: [floors, rooms]),
            ]);
      });

  Widget _buildStatusFilters(List<AutomationModel> matching) {
    final counts = {
      'All': matching.length,
      'Enabled': matching.where((routine) => routine.isEnabled).length,
      'Paused': matching.where((routine) => !routine.isEnabled).length,
    };
    final colors = Theme.of(context).colorScheme;
    return Wrap(spacing: 12, runSpacing: 8, children: [
      for (final entry in counts.entries)
        ChoiceChip(
          key: ValueKey('automation-status-${entry.key}'),
          label: Text('${entry.key}  ${entry.value}'),
          selected: _status == entry.key,
          showCheckmark: false,
          selectedColor: colors.primary,
          labelStyle: TextStyle(
              color:
                  _status == entry.key ? colors.onPrimary : colors.onSurface),
          shape: const StadiumBorder(),
          onSelected: (_) => setState(() => _status = entry.key),
        ),
    ]);
  }

  Widget _ruleLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 64,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value)),
        ]),
      );

  Widget _buildRoutineCard(AutomationModel routine) {
    final colors = Theme.of(context).colorScheme;
    final runs =
        sampleAutomationRuns.where((run) => run.automationId == routine.id);
    final lastRun = runs.isEmpty ? null : runs.first;
    final failed =
        routine.isEnabled && lastRun?.status == AutomationRunStatus.failed;
    final lastRunText = !routine.isEnabled
        ? 'Paused'
        : lastRun == null
            ? 'Not run yet'
            : failed
                ? 'Last run failed · ${lastRun.detail ?? 'Action failed'}'
                : 'Last run: ${lastRun.timeLabel}';
    return Card(
      key: ValueKey('automation-card-${routine.id}'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                    _triggerIcon(routine.trigger.type,
                        minutes: routine.trigger.minutesOfDay),
                    size: 30,
                    color: colors.primary)),
            const SizedBox(width: 16),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(routine.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (!routine.isEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('Paused',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ]),
            )),
            Switch(
              key: ValueKey('automation-switch-${routine.id}'),
              value: routine.isEnabled,
              onChanged: (value) => _setEnabled(routine, value),
            ),
            PopupMenuButton<String>(
              key: ValueKey('automation-menu-${routine.id}'),
              tooltip: 'Automation options',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditor(routine);
                }
                if (value == 'delete') {
                  _deleteRoutine(routine);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
          _ruleLine('WHEN', _triggerDescription(routine.trigger)),
          _ruleLine('THEN', routine.action.describe(_deviceTitles)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_roomIcon(routine.roomId),
                      size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(automationRoomLabels[routine.roomId] ?? routine.roomId),
                ]),
                Text(lastRunText,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            failed ? colors.primary : colors.onSurfaceVariant)),
              ]),
        ]),
      ),
    );
  }

  Widget _buildRunTile(AutomationRun run) {
    final colors = Theme.of(context).colorScheme;
    final completed = run.status == AutomationRunStatus.completed;
    final color = completed
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade700)
        : colors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(_triggerIcon(run.triggerType), size: 28, color: colors.primary),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(run.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(run.timeLabel,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(completed ? Icons.check_circle : Icons.error_outline,
                size: 14, color: color),
            const SizedBox(width: 6),
            Text(completed ? 'Completed' : 'Failed',
                style: TextStyle(color: color, fontSize: 12)),
          ]),
          if (run.detail != null) ...[
            const SizedBox(height: 4),
            Text(run.detail!, style: TextStyle(color: color, fontSize: 12)),
          ],
        ])),
      ]),
    );
  }

  void _showHistory() {
    final runs = _matchingRuns;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Run history'),
              content: SizedBox(
                width: 500,
                height: math.min(420, MediaQuery.sizeOf(context).height * .6),
                child: runs.isEmpty
                    ? const Center(child: Text('No runs in this selection'))
                    : ListView.separated(
                        itemCount: runs.length,
                        itemBuilder: (context, index) =>
                            _buildRunTile(runs[index]),
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'))
              ],
            ));
  }

  Widget _buildRecentRuns() {
    final runs = _matchingRuns.take(3).toList();
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Recent runs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        if (runs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No runs in this selection'),
          ),
        for (final run in runs) ...[
          _buildRunTile(run),
          const Divider(height: 1)
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _showHistory,
          child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('View history'),
                Icon(Icons.chevron_right),
              ]),
        ),
      ]),
    ));
  }

  Widget _buildRoutineList(List<AutomationModel> routines) {
    if (routines.isEmpty) {
      return const Card(
          child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(child: Text('No automations match your filters')),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var index = 0; index < routines.length; index++) ...[
        if (index > 0) const SizedBox(height: 12),
        _buildRoutineCard(routines[index]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final matching = _matchingAutomations;
    final visible = matching
        .where((routine) => switch (_status) {
              'Enabled' => routine.isEnabled,
              'Paused' => !routine.isEnabled,
              _ => true,
            })
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildFilters(),
        const SizedBox(height: 16),
        _buildStatusFilters(matching),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 950) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRoutineList(visible),
                  const SizedBox(height: 16),
                  _buildRecentRuns(),
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildRoutineList(visible)),
            const SizedBox(width: 16),
            SizedBox(width: 340, child: _buildRecentRuns()),
          ]);
        }),
      ]),
    );
  }
}
