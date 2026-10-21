import 'package:smart_home/src/models/devices/device_message.dart';

sealed class NotificationEvent {
  const NotificationEvent();
}

final class NotificationReceived extends NotificationEvent {
  const NotificationReceived(this.message);
  final DeviceMessage message;
}

final class NotificationRead extends NotificationEvent {
  const NotificationRead(this.sequence);

  final int sequence;
}

final class NotificationsReadAll extends NotificationEvent {
  const NotificationsReadAll();
}
