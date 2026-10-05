import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartPlugDeviceModel.dart';
import 'package:smart_home/src/models/rooms/roomEnvironmentModel.dart';
import 'package:smart_home/src/screen/home/widgets/addDeviceDialog.dart';
import 'package:smart_home/src/screen/home/widgets/fanDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/floorPlanView.dart';
import 'package:smart_home/src/screen/home/widgets/lightDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/smartPlugDeviceCard.dart';
import 'package:smart_home/src/dummyData/roomEnvironmentData.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedDeviceCetegory = 'All';
  String _searchquery = '';
  final TextEditingController _searchController = TextEditingController();
  final List<SmartDeviceModel> devices = createSmartDevices();
  String _selectedRoom = 'living';

  final Map<String, String> _roomLabels = {
    'living': 'Living Room',
    'kitchen': 'Kitchen',
    'bedroom1': 'Bedroom 1',
    'bathroom1': 'Bathroom 1',
  };

  bool _showRoomStats = false;
  VoidCallback? _resetFloorPlan;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDeviceCard(SmartDeviceModel device) {
    if (device is LightDeviceModel) {
      return LightDeviceCard(
        key: ValueKey(device.id),
        title: device.title,
        subtitle: device.subtitle,
        initialIsOn: device.isOn,
        brightness: device.brightness,
        onPowerChanged: (isOn) {
          setState(() {
            device.isOn = isOn;
          });
        },
        onBrightnessChanged: (brightness) {
          setState(() {
            device.brightness = brightness;
          });
        },
      );
    }
    if (device is FanDeviceModel) {
      return FanDeviceCard(
        key: ValueKey(device.id),
        title: device.title,
        subtitle: device.subtitle,
        initialIsOn: device.isOn,
        speed: device.speed,
        onPowerChanged: (isOn) {
          setState(() {
            device.isOn = isOn;
          });
        },
        onSpeedChanged: (speed) {
          setState(() {
            device.speed = speed;
          });
        },
      );
    }
    if (device is SmartPlugDeviceModel) {
      return SmartPlugDeviceCard(
        key: ValueKey(device.id),
        title: device.title,
        subtitle: device.subtitle,
        initialIsOn: device.isOn,
        onPowerChanged: (isOn) {
          setState(() {
            device.isOn = isOn;
          });
        },
      );
    }
    throw UnsupportedError('Unsupported device type');
  }

  int get _roomDeviceCount =>
      devices.where((device) => device.roomId == _selectedRoom).length;

  int get _roomActiveDeviceCount => devices
      .where((device) => device.roomId == _selectedRoom && device.isOn)
      .length;

  List<SmartDeviceModel> get _filteredDevices {
    final query = _searchquery.trim().toLowerCase();
    return devices.where((device) {
      if (device.roomId != _selectedRoom) {
        return false;
      }
      final matchesSearch = device.title.toLowerCase().contains(query) ||
          device.subtitle.toLowerCase().contains(query);

      if (!matchesSearch) {
        return false;
      }

      switch (_selectedDeviceCetegory) {
        case 'Lights':
          return device is LightDeviceModel;
        case 'Fans':
          return device is FanDeviceModel;
        case 'Plugs':
          return device is SmartPlugDeviceModel;
        default:
          return true;
      }
    }).toList();
  }

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
                value: '${environment.temperature.toStringAsFixed(1)}°C',
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
    final visibleDevices = _filteredDevices;

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
                              if (value == null || value == _selectedRoom)
                                return;
                              _searchController.clear();

                              setState(() {
                                _selectedRoom = value;
                                _selectedDeviceCetegory = 'All';
                                _searchquery = '';
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

                            _searchController.clear();

                            setState(() {
                              _selectedRoom = roomId;
                              _selectedDeviceCetegory = 'All';
                              _searchquery = '';
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _roomLabels[_selectedRoom] ?? 'Room',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final newDevice = await showDialog<SmartDeviceModel>(
                          context: context,
                          builder: (context) => AddDeviceDialog(
                            roomId: _selectedRoom,
                          ),
                        );
                        if (!mounted || newDevice == null) {
                          return;
                        }
                        setState(() {
                          devices.add(newDevice);
                        });
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add Device',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$_roomDeviceCount devices · $_roomActiveDeviceCount on',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search devices',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: _searchquery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear Search',
                            onPressed: () {
                              _searchController.clear();
                              setState(
                                () {
                                  _searchquery = '';
                                },
                              );
                            },
                          )
                        : null,
                  ),
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchquery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ['All', 'Lights', 'Fans', 'Plugs'])
                      ChoiceChip(
                        label: Text(_selectedDeviceCetegory == category
                            ? '$category  ${visibleDevices.length}'
                            : category),
                        selected: _selectedDeviceCetegory == category,
                        showCheckmark: false,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: _selectedDeviceCetegory == category
                              ? Colors.black
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDeviceCetegory = category;
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                Expanded(
                  child: visibleDevices.isEmpty
                      ? Center(
                          child: Text(
                            _roomDeviceCount == 0
                                ? 'No devices in this room yet'
                                : 'No devices match your search or category',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: visibleDevices.length,
                          itemBuilder: (context, index) {
                            return _buildDeviceCard(visibleDevices[index]);
                          },
                          separatorBuilder: (content, index) => const SizedBox(
                            height: 12,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
