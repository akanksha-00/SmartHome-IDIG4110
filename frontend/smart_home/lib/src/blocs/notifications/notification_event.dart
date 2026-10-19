import 'package:smart_home/src/models/notifications/notification_model.dart';

sealed class NotificationEvent {
  const NotificationEvent();
}

/// Supplies a local snapshot; no service or backend contract is required yet.
final class NotificationsLoaded extends NotificationEvent {
  NotificationsLoaded(List<NotificationModel> notifications)
      : notifications = List.unmodifiable(notifications);

  final List<NotificationModel> notifications;
}

final class NotificationRead extends NotificationEvent {
  const NotificationRead(this.id);

  final String id;
}

final class NotificationsReadAll extends NotificationEvent {
  const NotificationsReadAll();
}
