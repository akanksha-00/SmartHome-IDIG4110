import 'package:flutter/material.dart';
import 'package:smart_home/src/screen/home/homePage.dart';
import 'package:smart_home/src/screen/settings/settingsPage.dart';

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
      label: 'Security',
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
      page: const Center(child: Text('Security')),
    ),
    (
      label: 'Automations',
      icon: Icons.bolt_outlined,
      selectedIcon: Icons.bolt,
      page: const Center(child: Text('Automations')),
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
    final selectedDestination = _destinations[_selectedIndex];
    const user = "Alex";

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  color: Colors.amber,
                  size: 32,
                ),
                SizedBox(width: 16),
                Text('Welcome, $user'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 10),
                    SizedBox(width: 8),
                    Text('7 active devices', style: TextStyle(fontSize: 14)),
                  ],
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.thermostat_outlined,
                      color: Colors.amber,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Text('22°C Sunny', style: TextStyle(fontSize: 14)),
                  ],
                ),
                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Sat, 26 Sep',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(width: 16),
                Text(
                  '2:29 PM',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.amber),
            onPressed: () {
              // Handle notifications action
            },
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
                      // We'll add the profile page later.
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
