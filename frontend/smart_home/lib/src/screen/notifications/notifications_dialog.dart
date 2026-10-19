import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/models/notifications/notification_model.dart';

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
                        child: Text(
                            '${notifications.unreadCount + devices.unreadAlertCount} unread')),
                    TextButton(
                      onPressed: notifications.unreadCount == 0 &&
                              devices.unreadAlertCount == 0
                          ? null
                          : () {
                              context
                                  .read<NotificationBloc>()
                                  .add(const NotificationsReadAll());
                              context
                                  .read<DeviceBloc>()
                                  .add(const DeviceAlertsRead());
                            },
                      child: const Text('Mark all as read'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: notifications.notifications.isEmpty &&
                            devices.alerts.isEmpty
                        ? const Center(child: Text('No notifications to show'))
                        : ListView(
                            children: [
                              if (devices.alerts.isNotEmpty) ...[
                                const _SectionTitle('Device alerts'),
                                for (final alert in devices.alerts)
                                  Builder(builder: (context) {
                                    final device = devices.devices
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
                                            : Colors.grey,
                                      ),
                                      title: Text(alert.message),
                                      subtitle: Text([
                                        device?.name ?? alert.deviceId,
                                        if (room != null) room,
                                        alert.isActive ? 'Active' : 'Cleared',
                                      ].join(' · ')),
                                    );
                                  }),
                                const Divider(),
                              ],
                              if (notifications.notifications.isNotEmpty) ...[
                                const _SectionTitle('Demo notifications'),
                                for (final item in notifications.notifications)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _NotificationTile(item),
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.read<DeviceBloc>().add(const DeviceAlertsRead());
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.notification);
  final NotificationModel notification;

  void _read(BuildContext context) =>
      context.read<NotificationBloc>().add(NotificationRead(notification.id));

  String _timestamp(BuildContext context) {
    final createdAt = notification.createdAt.toLocal();
    final now = DateTime.now();
    final day = DateUtils.isSameDay(createdAt, now)
        ? 'Today'
        : DateUtils.isSameDay(
                createdAt, DateTime(now.year, now.month, now.day - 1))
            ? 'Yesterday'
            : MaterialLocalizations.of(context).formatShortDate(createdAt);
    return '$day, ${TimeOfDay.fromDateTime(createdAt).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (notification.severity) {
      NotificationSeverity.critical => (
          Icons.warning_amber_rounded,
          scheme.error
        ),
      NotificationSeverity.warning => (Icons.error_outline, scheme.primary),
      NotificationSeverity.info => (
          Icons.info_outline,
          scheme.onSurfaceVariant
        ),
    };
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
        key: ValueKey('notification-${notification.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(icon, color: color),
        title: Text(notification.title,
            style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 6),
            Text(_timestamp(context),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
