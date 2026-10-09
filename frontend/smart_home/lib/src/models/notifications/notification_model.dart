enum NotificationSeverity { info, warning, critical }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.isRead,
    this.deviceId,
    this.roomId,
  });

  final String id;
  final String title;
  final String message;
  final NotificationSeverity severity;
  final DateTime createdAt;
  final bool isRead;
  final String? deviceId;
  final String? roomId;
}
