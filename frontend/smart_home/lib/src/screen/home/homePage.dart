import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/models/rooms/roomEnvironmentModel.dart';
import 'package:smart_home/src/screen/home/widgets/device_panel.dart';
import 'package:smart_home/src/screen/home/widgets/floorPlanView.dart';
import 'package:smart_home/src/dummyData/roomEnvironmentData.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedRoom = 'living';

  final Map<String, String> _roomLabels = {
    'living': 'Living Room',
    'kitchen': 'Kitchen',
    'bedroom1': 'Bedroom 1',
    'bathroom1': 'Bathroom 1',
  };

  bool _showRoomStats = false;
  VoidCallback? _resetFloorPlan;

  RoomEnvironmentModel? get _selectedEnvironment =>
      roomEnvironments[_selectedRoom];

  Widget _buildRoomStatsCard() {
    final environment = _selectedEnvironment;

    if (environment == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Room environment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRoomStatRow(
                icon: Icons.air,
                label: 'Air quality',
                value: environment.airQuality,
              ),
              const SizedBox(height: 14),
              _buildRoomStatRow(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: AppSettingsScope.of(context)
                    .formatTemperature(environment.temperature, decimals: 1),
              ),
              const SizedBox(height: 14),
              _buildRoomStatRow(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${environment.humidity}%',
              ),
              const SizedBox(height: 14),
              _buildRoomStatRow(
                icon: Icons.people_outline,
                label: 'Occupancy',
                value: '${environment.occupancy} people',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomStatRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildScrollableFloorPanel({
    required Widget child,
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
                    _buildRoomStatsCard(),
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
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildScrollableFloorPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Column(
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
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Room'),
                          const SizedBox(height: 12),
                          DropdownMenu<String>(
                            width: 200,
                            initialSelection: _selectedRoom,
                            onSelected: (String? value) {
                              if (value == null || value == _selectedRoom) {
                                return;
                              }

                              setState(() {
                                _selectedRoom = value;
                              });
                            },
                            selectOnly: true,
                            dropdownMenuEntries: const [
                              DropdownMenuEntry(
                                  value: 'living', label: 'Living Room'),
                              DropdownMenuEntry(
                                  value: 'kitchen', label: 'Kitchen'),
                              DropdownMenuEntry(
                                  value: 'bedroom1', label: 'Bedroom 1'),
                              DropdownMenuEntry(
                                  value: 'bathroom1', label: 'Bathroom 1'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FloorPlanView(
                          selectedRoom: _selectedRoom,
                          onRoomSelected: (String roomId) {
                            if (roomId == _selectedRoom) return;

                            setState(() {
                              _selectedRoom = roomId;
                            });
                          },
                          onResetReady: (reset) {
                            _resetFloorPlan = reset;
                          },
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
            roomId: AppConfig.deviceRoomId(_selectedRoom),
            roomName: _roomLabels[_selectedRoom] ?? 'Room',
          ),
        ),
      ],
    );
  }
}
