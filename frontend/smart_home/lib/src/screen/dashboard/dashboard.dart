import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/screen/dashboard/dashboard_notifications.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/screen/automations/automations_page.dart';
import 'package:smart_home/src/screen/safety/safety_page.dart';
import 'package:smart_home/src/screen/home/homePage.dart';
import 'package:smart_home/src/screen/settings/settingsPage.dart';
import 'package:smart_home/src/screen/settings/widgets/settings_dialogs.dart';
import 'package:smart_home/src/screen/energy/energyPage.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  static final _destinations = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      page: const HomePage(),
    ),
    (
      label: 'Automations',
      icon: Icons.bolt_outlined,
      selectedIcon: Icons.bolt,
      page: const AutomationsPage(),
    ),
    (
      label: 'Energy',
      icon: Icons.energy_savings_leaf_outlined,
      selectedIcon: Icons.energy_savings_leaf,
      page: const EnergyPage(),
    ),
    (
      label: 'Safety',
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
      page: const SafetyPage(),
    ),
    (
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      page: const SettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final user = settings.profile.name;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.home_outlined,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text('Welcome, $user'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.thermostat_outlined,
                      color: Colors.amber,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text('${settings.formatTemperature(22)} Sunny',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ),
                const Text(
                  'Sat, 26 Sep',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Text(
                  '2:29 PM',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          BlocBuilder<RoomBloc, RoomState>(
            builder: (context, state) => DashboardNotifications(
              roomNames: {for (final room in state.rooms) room.id: room.name},
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).dividerTheme.color,
            height: 1,
          ),
        ),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    groupAlignment: -1.0,
                    extended: true,
                    destinations: [
                      for (final destination in _destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon, size: 28),
                          selectedIcon:
                              Icon(destination.selectedIcon, size: 28),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _selectedIndex = 4);
                      showProfileSettingsDialog(context, settings);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: Theme.of(context)
                          .navigationRailTheme
                          .unselectedIconTheme
                          ?.color,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Icon(Icons.person_outline, size: 28),
                        ),
                        Text('Profile', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                for (final destination in _destinations) destination.page,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
