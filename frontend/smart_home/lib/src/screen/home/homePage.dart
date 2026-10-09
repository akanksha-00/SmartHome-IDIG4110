import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/screen/home/widgets/device_panel.dart';
import 'package:smart_home/src/screen/home/widgets/floorPlanView.dart';
import 'package:smart_home/src/screen/home/widgets/room_selector.dart';
import 'package:smart_home/src/screen/home/widgets/room_environment_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showRoomStats = false;
  VoidCallback? _resetFloorPlan;

  Widget _buildScrollableFloorPanel({
    required Widget child,
    required String roomId,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < 700 ? 700 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    height: constraints.maxHeight < 550
                        ? 550
                        : constraints.maxHeight,
                    child: child,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: IconButton.filledTonal(
                onPressed: () {
                  _resetFloorPlan?.call();
                },
                icon: const Icon(Icons.refresh),
                iconSize: 30,
                padding: const EdgeInsets.all(16),
                tooltip: 'Reset view',
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_showRoomStats) ...[
                    RoomEnvironmentCard(roomId: roomId),
                    const SizedBox(height: 8),
                  ],
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _showRoomStats = !_showRoomStats;
                      });
                    },
                    icon: Icon(
                      _showRoomStats ? Icons.expand_more : Icons.info_outline,
                    ),
                    iconSize: 30,
                    padding: const EdgeInsets.all(16),
                    tooltip:
                        _showRoomStats ? 'Hide room stats' : 'Show room stats',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomBloc, RoomState>(
      listenWhen: (previous, current) =>
          previous.loadError != current.loadError && current.hasLoaded,
      listener: (context, state) {
        if (state.loadError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not refresh rooms')),
          );
        }
      },
      builder: (context, state) {
        final selectedRoom = state.selectedRoom;
        if (selectedRoom == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No rooms configured for this house'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: state.status == RoomLoadStatus.loading
                      ? null
                      : () => context
                          .read<RoomBloc>()
                          .add(const RoomsRequested(force: true)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh rooms'),
                ),
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildScrollableFloorPanel(
                  roomId: selectedRoom.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Floor'),
                              SizedBox(height: 12),
                              DropdownMenu(
                                width: 200,
                                initialSelection: 'floor1',
                                selectOnly: true,
                                dropdownMenuEntries: [
                                  DropdownMenuEntry(
                                      value: 'floor1', label: 'Floor 1'),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(width: 24),
                          RoomSelector(),
                        ],
                      ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            BlocBuilder<DeviceBloc, DeviceState>(
                              buildWhen: (previous, current) =>
                                  previous.devices != current.devices,
                              builder: (context, devices) => FloorPlanView(
                                rooms: state.rooms,
                                devices: devices.devices,
                                selectedRoom: selectedRoom.id,
                                onRoomSelected: (String roomId) {
                                  context
                                      .read<RoomBloc>()
                                      .add(RoomSelected(roomId));
                                },
                                onResetReady: (reset) {
                                  _resetFloorPlan = reset;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
            ),
            SizedBox(
              width: 480,
              child: DevicePanel(
                roomId: selectedRoom.id,
                roomName: selectedRoom.name,
              ),
            ),
          ],
        );
      },
    );
  }
}
