import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/dummyData/devicesData.dart';
import 'package:smart_home/src/dummyData/safety_data.dart';
import 'package:smart_home/src/dummyData/settings_data.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';
import 'package:smart_home/src/screen/settings/widgets/settings_dialogs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.controller});
  final AppSettingsController? controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showInfo(String title, Widget content) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: SizedBox(
                width: 480, child: SingleChildScrollView(child: content)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'))
            ],
          ));

  void _showRooms() => _showInfo(
      'Floors & rooms',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final floor in settingsFloors.values) ...[
            Text(floor,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final room in settingsRooms.values)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text(room)),
          ],
        ],
      ));

  void _showDevices() => _showInfo(
      'Device inventory',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Home devices',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final device in createSmartDevices())
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(device.title),
                subtitle: Text(
                    '${settingsRooms[device.roomId]} · ${device.subtitle}')),
          const Divider(),
          const Text('Safety devices',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final device in sampleSafetyDevices)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(device.title),
                subtitle: Text(
                    '${settingsRooms[device.roomId]} · ${device.location}')),
        ],
      ));

  Widget _valueRow(String key, String label, String value,
      {VoidCallback? onTap, String? actionLabel, bool disabled = false}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
        key: ValueKey('settings-row-$key'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: LayoutBuilder(builder: (context, constraints) {
            final action = actionLabel == null
                ? onTap == null
                    ? const SizedBox.shrink()
                    : const Icon(Icons.chevron_right, size: 20)
                : Text(actionLabel, style: TextStyle(color: colors.primary));
            final valueText =
                Text(value, style: TextStyle(color: colors.onSurfaceVariant));
            final labelText = Text(label,
                style: TextStyle(
                    color: disabled ? colors.onSurfaceVariant : null));
            if (constraints.maxWidth < 420) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    labelText,
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: valueText),
                      const SizedBox(width: 12),
                      action
                    ]),
                  ]);
            }
            return Row(children: [
              Expanded(child: labelText),
              const SizedBox(width: 12),
              Expanded(child: valueText),
              const SizedBox(width: 12),
              action
            ]);
          }),
        ));
  }

  Widget _switchRow(
          String key, String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Switch(
              key: ValueKey('settings-switch-$key'),
              value: value,
              onChanged: onChanged)
        ]),
      );

  Widget _controlRow(String label, Widget control, {double width = 300}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < width + 140) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: math.min(width, constraints.maxWidth),
                      child: control)
                ]);
          }
          return Row(children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            SizedBox(width: width, child: control)
          ]);
        }),
      );

  ButtonStyle _segmentedStyle() {
    final colors = Theme.of(context).colorScheme;
    return SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.primary,
        selectedForegroundColor: colors.onPrimary);
  }

  List<_SettingsSection> _sections(AppSettingsController settings) => [
        _SettingsSection('Home', Icons.home_outlined, [
          _SettingsEntry(
              'Home name ${settings.homeName}',
              _valueRow('home-name', 'Home name', settings.homeName,
                  actionLabel: 'Edit',
                  onTap: () => showHomeNameDialog(context, settings))),
          _SettingsEntry(
              'Floors rooms layout',
              _valueRow('rooms', 'Floors & rooms',
                  '${settingsFloors.length} floor · ${settingsRooms.length} rooms',
                  onTap: _showRooms)),
          _SettingsEntry(
              'Time zone ${settings.timeZone}',
              _valueRow('time-zone', 'Time zone', settings.timeZone,
                  onTap: () => showTimeZoneDialog(context, settings))),
        ]),
        _SettingsSection('Devices & connections', Icons.devices_outlined, [
          _SettingsEntry(
              'Device inventory lights fans plugs sensors',
              _valueRow('devices', 'Device inventory', 'Lights, fans & sensors',
                  onTap: _showDevices)),
          _SettingsEntry(
              'Connections integrations',
              _valueRow('connections', 'Connections', 'Not configured',
                  onTap: () => _showInfo(
                      'Connections',
                      const Text(
                          'Device integrations will appear here when connected to your home.')))),
          _SettingsEntry(
              'Connection status local',
              _valueRow(
                  'connection-status', 'Connection status', 'Local preview')),
        ]),
        _SettingsSection('Notifications', Icons.notifications_outlined, [
          _SettingsEntry(
              'Safety alerts delivery push email',
              _valueRow(
                  'safety-delivery', 'Safety alerts', 'Configure delivery',
                  onTap: () => showSafetyDeliveryDialog(context, settings))),
          _SettingsEntry(
              'Device offline alerts',
              _switchRow('offline', 'Device offline alerts',
                  settings.offlineAlerts, settings.setOfflineAlerts)),
          _SettingsEntry(
              'Automation updates',
              _switchRow('automations', 'Automation updates',
                  settings.automationUpdates, settings.setAutomationUpdates)),
          const _SettingsEntry(
              'Safety monitoring notification preferences',
              Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Notification preferences do not disable safety monitoring.',
                                style: TextStyle(fontSize: 12)))
                      ]))),
        ]),
        _SettingsSection('Household access', Icons.people_outline, [
          _SettingsEntry(
              'Household members access',
              _valueRow('members', 'Household members',
                  '${settings.members.length} people',
                  onTap: () => showHouseholdDialog(context, settings))),
          _SettingsEntry(
              'Your role owner', _valueRow('role', 'Your role', 'Owner')),
          _SettingsEntry(
              'Member roles admin guest permissions',
              _valueRow('member-roles', 'Member roles', 'Admin, member & guest',
                  onTap: () => _showInfo(
                      'Household roles',
                      const Text(
                          'Each household member has a role. The home owner manages household membership.')))),
        ]),
        _SettingsSection('Appearance & preferences', Icons.palette_outlined, [
          _SettingsEntry(
              'Theme light dark system',
              _controlRow(
                  'Theme',
                  SegmentedButton<ThemeMode>(
                    key: const ValueKey('settings-theme'),
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    style: _segmentedStyle(),
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(
                          value: ThemeMode.system, label: Text('System'))
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) =>
                        settings.setThemeMode(value.first),
                  ))),
          _SettingsEntry(
              'Temperature unit celsius fahrenheit',
              _controlRow(
                  'Temperature unit',
                  SegmentedButton<TemperatureUnit>(
                    key: const ValueKey('settings-temperature'),
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    style: _segmentedStyle(),
                    segments: const [
                      ButtonSegment(
                          value: TemperatureUnit.celsius, label: Text('°C')),
                      ButtonSegment(
                          value: TemperatureUnit.fahrenheit, label: Text('°F'))
                    ],
                    selected: {settings.temperatureUnit},
                    onSelectionChanged: (value) =>
                        settings.setTemperatureUnit(value.first),
                  ),
                  width: 220)),
          _SettingsEntry(
              'Language English',
              _valueRow('language', 'Language', 'English',
                  onTap: () => _showInfo(
                      'Language',
                      const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('English'),
                          trailing: Icon(Icons.check))))),
        ]),
        _SettingsSection('Account & app', Icons.person_outline, [
          _SettingsEntry(
              'Profile ${settings.profile.name} ${settings.profile.email}',
              _valueRow('profile', 'Profile', settings.profile.name,
                  onTap: () => showProfileSettingsDialog(context, settings))),
          _SettingsEntry(
              'Privacy data session',
              _valueRow('privacy', 'Privacy & data', 'View information',
                  onTap: () => _showInfo(
                      'Privacy & data',
                      const Text(
                          'Home details and preferences are kept for this app session. Account sign-in, cloud sync and external notification delivery are not connected yet.')))),
          _SettingsEntry(
              'About version licenses',
              _valueRow('about', 'About', 'Smart Home · 1.0.0',
                  onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Smart Home',
                      applicationVersion: '1.0.0',
                      applicationIcon:
                          const Icon(Icons.home_outlined, size: 36)))),
          _SettingsEntry(
              'Sign out account session',
              _valueRow('sign-out', 'Sign out', 'No signed-in session',
                  disabled: true)),
        ]),
      ];

  Widget _sectionCard(_SettingsSection section, List<_SettingsEntry> entries) =>
      Card(
        key: ValueKey('settings-section-${section.title}'),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(section.icon, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(section.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)))
                  ]),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  for (var index = 0; index < entries.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    entries[index].widget,
                  ],
                ])),
      );

  Widget _buildHeader() => LayoutBuilder(builder: (context, constraints) {
        const title = Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
        final search = TextField(
          key: const ValueKey('settings-search'),
          controller: _search,
          decoration: InputDecoration(
              hintText: 'Search settings',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                            _query = '';
                            _search.clear();
                          }))),
          onChanged: (value) => setState(() => _query = value),
        );
        if (constraints.maxWidth < 560) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 16), search]);
        }
        return Row(children: [
          const Expanded(child: title),
          const SizedBox(width: 16),
          SizedBox(width: 300, child: search)
        ]);
      });

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller ?? AppSettingsScope.of(context);
    return ListenableBuilder(
        listenable: settings,
        builder: (context, child) {
          final query = _query.trim().toLowerCase();
          final cards = <Widget>[];
          for (final section in _sections(settings)) {
            final entries = section.title.toLowerCase().contains(query)
                ? section.entries
                : section.entries
                    .where(
                        (entry) => entry.search.toLowerCase().contains(query))
                    .toList();
            if (entries.isNotEmpty) cards.add(_sectionCard(section, entries));
          }
          return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (cards.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                            child: Text('No settings match your search'))),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 0;
                                index < cards.length;
                                index++) ...[
                              if (index > 0) const SizedBox(height: 16),
                              cards[index]
                            ]
                          ]);
                    }
                    final width = (constraints.maxWidth - 16) / 2;
                    return Wrap(spacing: 16, runSpacing: 16, children: [
                      for (final card in cards)
                        SizedBox(width: width, child: card)
                    ]);
                  }),
                ],
              ));
        });
  }
}

class _SettingsEntry {
  const _SettingsEntry(this.search, this.widget);
  final String search;
  final Widget widget;
}

class _SettingsSection {
  const _SettingsSection(this.title, this.icon, this.entries);
  final String title;
  final IconData icon;
  final List<_SettingsEntry> entries;
}
