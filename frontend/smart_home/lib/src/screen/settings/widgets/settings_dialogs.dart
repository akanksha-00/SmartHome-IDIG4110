import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/dummyData/settings_data.dart';
import 'package:smart_home/src/models/settings/settings_model.dart';

Future<void> showHomeNameDialog(
    BuildContext context, AppSettingsController settings) async {
  final value = await showDialog<String>(
      context: context,
      builder: (context) => _HomeNameDialog(value: settings.homeName));
  if (value != null) settings.setHomeName(value);
}

class _HomeNameDialog extends StatefulWidget {
  const _HomeNameDialog({required this.value});
  final String value;
  @override
  State<_HomeNameDialog> createState() => _HomeNameDialogState();
}

class _HomeNameDialogState extends State<_HomeNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Home name'),
        content: SizedBox(
            width: 400,
            child: Form(
                key: _form,
                child: TextFormField(
                  key: const ValueKey('settings-home-name'),
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Home name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a home name'
                      : null,
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context).pop(_name.text.trim());
                }
              },
              child: const Text('Save')),
        ],
      );
}

typedef _PersonDetails = ({String name, String email, HouseholdRole role});
Future<void> showProfileSettingsDialog(
    BuildContext context, AppSettingsController settings) async {
  final value = await showDialog<_PersonDetails>(
      context: context,
      builder: (context) => _PersonDialog(settings: settings));
  if (value != null) {
    settings.setProfile(ProfileDetails(name: value.name, email: value.email));
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({required this.settings, this.member = false});
  final AppSettingsController settings;
  final bool member;
  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: widget.member ? '' : widget.settings.profile.name);
  late final _email = TextEditingController(
      text: widget.member ? '' : widget.settings.profile.email);
  HouseholdRole _role = HouseholdRole.member;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.member ? 'Add household member' : 'Profile'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                            key: const ValueKey('settings-profile-name'),
                            controller: _name,
                            maxLength: 60,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter a name'
                                    : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            key: const ValueKey('settings-profile-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(email)) {
                                return 'Enter a valid email';
                              }
                              if (widget.settings.members.any((member) =>
                                  member.email.toLowerCase() ==
                                      email.toLowerCase() &&
                                  (widget.member ||
                                      member.role != HouseholdRole.owner))) {
                                return 'This email is already in the household';
                              }
                              return null;
                            }),
                        if (widget.member) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<HouseholdRole>(
                              initialValue: _role,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Role'),
                              items: const [
                                DropdownMenuItem(
                                    value: HouseholdRole.admin,
                                    child: Text('Admin')),
                                DropdownMenuItem(
                                    value: HouseholdRole.member,
                                    child: Text('Member')),
                                DropdownMenuItem(
                                    value: HouseholdRole.guest,
                                    child: Text('Guest')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _role = value);
                                }
                              }),
                        ],
                      ],
                    )))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context).pop((
                    name: _name.text.trim(),
                    email: _email.text.trim(),
                    role: _role
                  ));
                }
              },
              child: const Text('Save')),
        ],
      );
}

void showHouseholdDialog(
        BuildContext context, AppSettingsController settings) =>
    showDialog<void>(
        context: context,
        builder: (context) => _HouseholdDialog(settings: settings));

class _HouseholdDialog extends StatelessWidget {
  const _HouseholdDialog({required this.settings});
  final AppSettingsController settings;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: settings,
      builder: (context, child) => AlertDialog(
            title: const Text('Household access'),
            content: SizedBox(
                width: 500,
                height: 300,
                child: ListView.separated(
                  itemCount: settings.members.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = settings.members[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.name),
                      subtitle: Text('${member.email}\n${member.role.name}'),
                      isThreeLine: true,
                      trailing: member.role == HouseholdRole.owner
                          ? const Icon(Icons.verified_user_outlined)
                          : IconButton(
                              tooltip: 'Remove ${member.name}',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () =>
                                  settings.removeMember(member.id)),
                    );
                  },
                )),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close')),
              FilledButton.icon(
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add member'),
                  onPressed: () async {
                    final value = await showDialog<_PersonDetails>(
                        context: context,
                        builder: (context) =>
                            _PersonDialog(settings: settings, member: true));
                    if (value != null) {
                      settings.addMember(HouseholdMember(
                          id: 'member-${DateTime.now().microsecondsSinceEpoch}',
                          name: value.name,
                          email: value.email,
                          role: value.role));
                    }
                  }),
            ],
          ));
}

Future<void> showTimeZoneDialog(
    BuildContext context, AppSettingsController settings) async {
  final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
            title: const Text('Time zone'),
            children: [
              for (final zone in settingsTimeZones)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(zone),
                  child: Row(children: [
                    Expanded(child: Text(zone)),
                    if (zone == settings.timeZone) const Icon(Icons.check)
                  ]),
                )
            ],
          ));
  if (value != null) settings.setTimeZone(value);
}

void showSafetyDeliveryDialog(
        BuildContext context, AppSettingsController settings) =>
    showDialog<void>(
        context: context,
        builder: (context) => _SafetyDeliveryDialog(settings: settings));

class _SafetyDeliveryDialog extends StatefulWidget {
  const _SafetyDeliveryDialog({required this.settings});
  final AppSettingsController settings;
  @override
  State<_SafetyDeliveryDialog> createState() => _SafetyDeliveryDialogState();
}

class _SafetyDeliveryDialogState extends State<_SafetyDeliveryDialog> {
  late final _selected =
      Set<AlertDelivery>.of(widget.settings.safetyAlertDelivery);
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Safety alert delivery'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final delivery in AlertDelivery.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (delivery) {
                    AlertDelivery.inApp => 'In-app alerts',
                    AlertDelivery.push => 'Push notifications',
                    AlertDelivery.email => 'Email alerts'
                  }),
                  value: _selected.contains(delivery),
                  onChanged: (value) => setState(() {
                    value
                        ? _selected.add(delivery)
                        : _selected.remove(delivery);
                  }),
                ),
              const SizedBox(height: 8),
              const Text(
                  'Notification preferences do not disable safety monitoring.'),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                widget.settings.setSafetyAlertDelivery(_selected);
                Navigator.of(context).pop();
              },
              child: const Text('Save')),
        ],
      );
}
