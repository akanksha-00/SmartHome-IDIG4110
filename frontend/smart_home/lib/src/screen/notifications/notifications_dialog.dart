import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/models/notifications/device_alert.dart';

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key, this.roomNames = const {}});

  final Map<String, String> roomNames;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, notifications) =>
            BlocBuilder<DeviceBloc, DeviceState>(
          builder: (context, devices) => AlertDialog(
            title: const Text('Notifications'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('${notifications.unreadCount} unread')),
                    TextButton(
                      onPressed: notifications.unreadCount == 0
                          ? null
                          : () {
                              context
                                  .read<NotificationBloc>()
                                  .add(const NotificationsReadAll());
                            },
                      child: const Text('Mark all as read'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: notifications.notifications.isEmpty
                        ? const Center(child: Text('No notifications to show'))
                        : ListView.separated(
                            itemCount: notifications.notifications.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final alert = notifications.notifications[index];
                              final device = devices.devices
                                  .where((d) => d.id == alert.deviceId)
                                  .firstOrNull;
                              final room =
                                  roomNames[device?.roomId] ?? device?.roomId;
                              return _NotificationTile(
                                notification: alert,
                                deviceName: device?.name,
                                roomName: room,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(
      {required this.notification, this.deviceName, this.roomName});
  final DeviceAlert notification;
  final String? deviceName;
  final String? roomName;

  void _read(BuildContext context) => context
      .read<NotificationBloc>()
      .add(NotificationRead(notification.sequence));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : scheme.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('notification-${notification.sequence}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          notification.isActive
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
          color: notification.isActive ? scheme.error : scheme.onSurfaceVariant,
        ),
        title: Text(notification.message,
            style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.w600)),
        subtitle: Text([
          deviceName ?? notification.deviceId,
          if (roomName != null) roomName!,
          notification.isActive ? 'Active' : 'Cleared',
        ].join(' · ')),
        trailing: notification.isRead
            ? const Icon(Icons.done, size: 20, semanticLabel: 'Read')
            : IconButton(
                tooltip: 'Mark as read',
                onPressed: () => _read(context),
                icon: const Icon(Icons.mark_email_read_outlined, size: 20),
              ),
        onTap: notification.isRead ? null : () => _read(context),
      ),
    );
  }
}
