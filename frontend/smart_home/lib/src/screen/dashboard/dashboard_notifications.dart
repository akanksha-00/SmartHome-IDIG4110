import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/screen/notifications/notifications_dialog.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

class DashboardNotifications extends StatelessWidget {
  const DashboardNotifications({super.key, this.roomNames = const {}});
  final Map<String, String> roomNames;

  void _open(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final bloc = context.read<DeviceBloc>();
    showDialog<void>(
        context: context,
        builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: bloc),
                BlocProvider.value(value: context.read<NotificationBloc>()),
              ],
              child: NotificationsDialog(roomNames: roomNames),
            ));
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<NotificationBloc, NotificationState>(
        listenWhen: (previous, current) =>
            previous.latestSequence != current.latestSequence,
        listener: (context, state) {
          if (state.notifications.isEmpty) return;
          final alert = state.notifications.first;
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
        builder: (context, notifications) =>
            BlocBuilder<DeviceBloc, DeviceState>(
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
                key: const ValueKey('app-bar-notifications'),
                tooltip: 'Notifications',
                onPressed: () => _open(context),
                icon: Badge(
                  isLabelVisible: notifications.unreadCount > 0,
                  label: Text(notifications.unreadCount > 99
                      ? '99+'
                      : '${notifications.unreadCount}'),
                  child: const Icon(Icons.notifications, color: Colors.amber),
                ),
              ),
            ]);
          },
        ),
      );
}
