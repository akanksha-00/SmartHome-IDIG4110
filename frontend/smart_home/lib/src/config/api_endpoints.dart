/// URLs verified against the Smart Home API's OpenAPI specification.
class ApiEndpoints {
  ApiEndpoints._();

  // Keep this without a trailing slash.
  static const String baseUrl = 'https://smarthome-api.abdi-bako.workers.dev';
  static const String apiRoot = '$baseUrl/api/v1';
  static const String houses = '$apiRoot/houses';

  static String devices(String houseId) =>
      '$houses/${_segment(houseId)}/devices';

  static String device(String houseId, String deviceId) =>
      '${devices(houseId)}/${_segment(deviceId)}';

  static String roomDevices(String houseId, String roomId) =>
      '$houses/${_segment(houseId)}/rooms/${_segment(roomId)}/devices';

  // No routes for these feeds are published yet. Configure after verification.
  static const String? sensorData = null;
  static const String? notifications = null;

  static String _segment(String id) {
    if (id.trim().isEmpty) throw ArgumentError('API path ID is required');
    return Uri.encodeComponent(id);
  }
}
