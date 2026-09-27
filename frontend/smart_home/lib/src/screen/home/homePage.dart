import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/models/devices/fanDeviceModel.dart';
import 'package:smart_home/src/models/devices/lightDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartDeviceModel.dart';
import 'package:smart_home/src/models/devices/smartPlugDeviceModel.dart';
import 'package:smart_home/src/screen/home/widgets/fanDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/lightDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/smartPlugDeviceCard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedDeviceCetegory = 'All';
  String _searchquery = '';
  final List<SmartDeviceModel> devices = createSmartDevices();

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

  int get _activeDevicesCount {
    return (devices.where((device) => device.isOn)).length;
  }

  List<SmartDeviceModel> get _filteredDevices {
    final query = _searchquery.trim().toLowerCase();
    return devices.where((device) {
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

  @override
  Widget build(BuildContext context) {
    final visibleDevices = _filteredDevices;

    return Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Floor'),
                        SizedBox(height: 12),
                        DropdownMenu(
                          width: 200,
                          initialSelection: 'ground',
                          selectOnly: true,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                                value: 'ground', label: 'Ground Floor'),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room'),
                        SizedBox(height: 12),
                        DropdownMenu(
                          width: 200,
                          initialSelection: 'living',
                          selectOnly: true,
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                                value: 'living', label: 'Living Room'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Text('Floor Plan'),
                  ),
                ),
              ],
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
                    const Expanded(
                      child: Text(
                        'Living Room',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Add Device',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${devices.length} devices · $_activeDevicesCount on',
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
                  ),
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
                      ? const Center(
                          child: Text(
                            'No devices to show',
                            style: TextStyle(
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
