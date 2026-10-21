import 'package:smart_home/src/models/notifications/device_alert.dart';

class NotificationState {
  NotificationState({List<DeviceAlert> notifications = const []})
      : notifications = List.unmodifiable(notifications);

  final List<DeviceAlert> notifications;

  int get unreadCount => notifications.where((item) => !item.isRead).length;
  int get latestSequence => notifications.firstOrNull?.sequence ?? 0;
}
