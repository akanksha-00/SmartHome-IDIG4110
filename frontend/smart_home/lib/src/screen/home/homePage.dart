import 'package:flutter/material.dart';
import 'package:smart_home/src/screen/home/widgets/fanDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/lightDeviceCard.dart';
import 'package:smart_home/src/screen/home/widgets/smartPlugDeviceCard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLightOn = true;
  double _brightness = 0.5;

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '8 devices · 5 on',
                  style: TextStyle(
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
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: const Text('All 8'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      labelStyle: const TextStyle(color: Colors.black),
                      side: BorderSide.none,
                    ),
                    const Chip(
                      label: Text('Lights'),
                    ),
                    const Chip(
                      label: Text('Fans'),
                    ),
                    const Chip(
                      label: Text('Plugs'),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                Expanded(
                  child: ListView(
                    children: const [
                      LightDeviceCard(
                        title: 'Ceiling Light 1',
                        subtitle: 'Above sofa',
                        initialIsOn: false,
                        initialValue: 0.0,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      LightDeviceCard(
                        title: 'Ceiling Light 2',
                        subtitle: 'Above dining table',
                        initialIsOn: false,
                        initialValue: 0.0,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      LightDeviceCard(
                        title: 'Ceiling Light 3',
                        subtitle: 'Above entrance',
                        initialIsOn: false,
                        initialValue: 0.0,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      FanDeviceCard(
                        title: 'Ceiling Fan 1',
                        subtitle: 'Sofa area',
                        initialIsOn: false,
                        initialSpeed: 2,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      FanDeviceCard(
                        title: 'Ceiling Fan 2',
                        subtitle: 'Dining area',
                        initialIsOn: false,
                        initialSpeed: 1,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      SmartPlugDeviceCard(
                        title: 'TV plug',
                        subtitle: 'TV wall',
                        initialIsOn: false,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      SmartPlugDeviceCard(
                        title: 'Speaker plug',
                        subtitle: 'TV wall',
                        initialIsOn: false,
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
