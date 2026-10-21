import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

class DashboardNotifications extends StatelessWidget {
  const DashboardNotifications({super.key, this.roomNames = const {}});
  final Map<String, String> roomNames;

  void _open(BuildContext context) {
    final bloc = context.read<DeviceBloc>();
    bloc.add(const DeviceAlertsRead());
    showDialog<void>(
        context: context,
        builder: (_) => BlocProvider.value(
              value: bloc,
              child: BlocBuilder<DeviceBloc, DeviceState>(
                  builder: (context, state) => AlertDialog(
                        title: const Text('Notifications'),
                        content: SizedBox(
                          width: 440,
                          height: 360,
                          child: state.alerts.isEmpty
                              ? const Center(
                                  child:
                                      Text('No alerts received this session'))
                              : ListView.separated(
                                  itemCount: state.alerts.length,
                                  separatorBuilder: (_, index) =>
                                      const Divider(),
                                  itemBuilder: (context, index) {
                                    final alert = state.alerts[index];
                                    final device = state.devices
                                        .where((d) => d.id == alert.deviceId)
                                        .firstOrNull;
                                    final room = roomNames[device?.roomId] ??
                                        device?.roomId;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                          alert.isActive
                                              ? Icons.warning_amber
                                              : Icons.check_circle_outline,
                                          color: alert.isActive
                                              ? Colors.redAccent
                                              : Colors.grey),
                                      title: Text(alert.message),
                                      subtitle: Text([
                                        device?.name ?? alert.deviceId,
                                        if (room != null) room,
                                        alert.isActive ? 'Active' : 'Cleared',
                                      ].join(' · ')),
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () {
                                bloc.add(const DeviceAlertsRead());
                                Navigator.of(context).pop();
                              },
                              child: const Text('Close'))
                        ],
                      )),
            ));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<DeviceBloc, DeviceState>(
        listenWhen: (previous, current) =>
            previous.alertRevision != current.alertRevision,
        listener: (context, state) {
          if (state.alerts.isEmpty) return;
          final alert = state.alerts.first;
          if (!alert.isActive) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 8),
            content: Row(children: [
              const Icon(Icons.warning_amber, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(child: Text(alert.message)),
            ]),
            action:
                SnackBarAction(label: 'View', onPressed: () => _open(context)),
          ));
        },
        builder: (context, state) {
          final live = state.connection == SocketConnectionState.connected;
          final label = live ? 'Live' : 'Reconnecting';
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (state.realtimeEnabled)
              Tooltip(
                message: state.streamError != null
                    ? 'Live update error: ${state.streamError}'
                    : live
                        ? 'Receiving house updates'
                        : 'Showing cached data; controls wait for reconnection',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      state.streamError != null
                          ? Icons.error_outline
                          : Icons.circle,
                      size: 12,
                      color: live && state.streamError == null
                          ? Colors.greenAccent
                          : Colors.amber),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                ]),
              ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _open(context),
              icon: Badge(
                isLabelVisible: state.unreadAlertCount > 0,
                label: Text('${state.unreadAlertCount}'),
                child: const Icon(Icons.notifications, color: Colors.amber),
              ),
            ),
          ]);
        },
      );
}
