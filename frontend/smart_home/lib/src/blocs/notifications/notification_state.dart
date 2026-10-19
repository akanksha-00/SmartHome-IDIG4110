import 'package:smart_home/src/models/notifications/notification_model.dart';

class NotificationState {
  NotificationState({List<NotificationModel> notifications = const []})
      : notifications = List.unmodifiable(notifications);

  final List<NotificationModel> notifications;

  int get unreadCount => notifications.where((item) => !item.isRead).length;
}
