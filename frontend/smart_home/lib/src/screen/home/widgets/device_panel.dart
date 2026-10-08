import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/screen/home/widgets/addDeviceDialog.dart';
import 'package:smart_home/src/screen/home/widgets/api_device_card.dart';

/// All persisted device values come from DeviceBloc. Search/category are local UI.
class DevicePanel extends StatefulWidget {
  const DevicePanel({super.key, required this.roomId, required this.roomName});
  final String roomId;
  final String roomName;

  @override
  State<DevicePanel> createState() => _DevicePanelState();
}

class _DevicePanelState extends State<DevicePanel> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DevicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _searchController.clear();
      _query = '';
      _category = 'All';
    }
  }

  String _subtitle(ApiDevice device) {
    final metadata = [device.manufacturer, device.model]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    return metadata.isEmpty ? widget.roomName : metadata;
  }

  bool _matches(ApiDevice device) {
    final query = _query.trim().toLowerCase();
    final search =
        '${device.name} ${_subtitle(device)}'.toLowerCase().contains(query);
    final category = switch (_category) {
      'Lights' => device.type.toLowerCase() == 'light',
      'Fans' => device.type.toLowerCase() == 'fan',
      'Plugs' => ['plug', 'smart_plug'].contains(device.type.toLowerCase()),
      _ => true,
    };
    return search && category;
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<DeviceBloc, DeviceState>(
        listenWhen: (previous, current) =>
            previous.updateErrorRevision != current.updateErrorRevision ||
            previous.loadError != current.loadError,
        listener: (context, state) {
          final error = state.updateError ?? state.loadError;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not update devices: $error'),
            ));
          }
        },
        builder: (context, state) {
          final roomDevices = state.devices
              .where((device) => device.roomId == widget.roomId)
              .toList();
          final visibleDevices = roomDevices.where(_matches).toList();
          final onCount = roomDevices
              .where((device) => device.state['power'] == true)
              .length;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(widget.roomName,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600))),
                  OutlinedButton.icon(
                    onPressed: state.isAdding ||
                            state.status == DeviceLoadStatus.loading
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (_) => BlocProvider.value(
                                value: context.read<DeviceBloc>(),
                                child: AddDeviceDialog(
                                    roomId: widget.roomId,
                                    roomName: widget.roomName),
                              ),
                            ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Device'),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('${roomDevices.length} devices · $onCount on',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('device-search'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search devices',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear Search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final category in ['All', 'Lights', 'Fans', 'Plugs'])
                    ChoiceChip(
                      label: Text(_category == category
                          ? '$category  ${visibleDevices.length}'
                          : category),
                      selected: _category == category,
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                          color: _category == category ? Colors.black : null),
                      onSelected: (selected) {
                        if (selected) setState(() => _category = category);
                      },
                    ),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: visibleDevices.isEmpty
                      ? Center(
                          child: Text(
                              roomDevices.isEmpty
                                  ? 'No devices in this room yet'
                                  : 'No devices match your search or category',
                              style: const TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: visibleDevices.length,
                          itemBuilder: (context, index) {
                            final device = visibleDevices[index];
                            final pending =
                                state.pendingDeviceIds.contains(device.id);
                            return Column(
                                key: ValueKey(device.id),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ApiDeviceCard(
                                    device: device,
                                    subtitle: _subtitle(device),
                                    isUpdating: pending ||
                                        state.status ==
                                            DeviceLoadStatus.loading,
                                    onStateChanged: (updates) => context
                                        .read<DeviceBloc>()
                                        .add(DeviceStateUpdateRequested(
                                            id: device.id, updates: updates)),
                                  ),
                                  if (pending)
                                    const Padding(
                                      padding:
                                          EdgeInsets.only(left: 16, top: 4),
                                      child: Text('Updating…',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ),
                                ]);
                          },
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                        ),
                ),
              ],
            ),
          );
        },
      );
}
