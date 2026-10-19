import 'package:smart_home/src/models/notifications/notification_model.dart';

/// Demo entries only. These are never sent to or inferred from the backend.
List<NotificationModel> dummyNotifications({DateTime? now}) {
  final time = now ?? DateTime.now();
  return [
    NotificationModel(
      id: 'demo-smoke',
      title: 'Smoke detector alert',
      message: 'Smoke detected in Bedroom 1. This is a demonstration alert.',
      severity: NotificationSeverity.critical,
      createdAt: time.subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    NotificationModel(
      id: 'demo-temperature',
      title: 'Room temperature is high',
      message: 'Living Room temperature has reached 31°C.',
      severity: NotificationSeverity.warning,
      createdAt: time.subtract(const Duration(minutes: 20)),
      isRead: false,
    ),
    NotificationModel(
      id: 'demo-device-offline',
      title: 'Device is offline',
      message: 'The kitchen fan is not responding.',
      severity: NotificationSeverity.warning,
      createdAt: time.subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    NotificationModel(
      id: 'demo-automation',
      title: 'Morning lights completed',
      message: 'The Living Room lights were switched on.',
      severity: NotificationSeverity.info,
      createdAt: time.subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    NotificationModel(
      id: 'demo-device-added',
      title: 'New device added',
      message: 'A smart plug was added to the Kitchen.',
      severity: NotificationSeverity.info,
      createdAt: time.subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];
}
