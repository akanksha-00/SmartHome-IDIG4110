import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/models/notifications/notification_model.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/api_json.dart';

/// Draft feed contract; the published backend has no notification route.
class NotificationRepository {
  const NotificationRepository(
      {required this.apiClient, this.endpoint = ApiEndpoints.notifications});

  final ApiClient apiClient;
  final String? endpoint;

  /// Alerts share this feed, with warning or critical severity.
  Future<List<NotificationModel>> fetchNotifications({String? roomId}) async {
    final url = endpoint;
    if (url == null || url.trim().isEmpty) {
      throw UnsupportedError('No notification endpoint is published yet');
    }
    final response = await apiClient.get(
      url,
      queryParameters: {if (roomId != null) 'roomId': roomId},
    );
    return jsonObjects(response).map((json) {
      final severity = switch (jsonString(json, 'severity')) {
        'info' => NotificationSeverity.info,
        'warning' => NotificationSeverity.warning,
        'critical' => NotificationSeverity.critical,
        _ => throw const FormatException('Unsupported notification severity'),
      };
      return NotificationModel(
        id: jsonString(json, 'id'),
        title: jsonString(json, 'title'),
        message: jsonString(json, 'message'),
        severity: severity,
        createdAt: jsonDate(json, 'createdAt'),
        isRead: jsonBool(json, 'isRead'),
        deviceId: jsonOptionalString(json, 'deviceId'),
        roomId: jsonOptionalString(json, 'roomId'),
      );
    }).toList();
  }
}
