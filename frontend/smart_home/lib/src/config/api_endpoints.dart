/// URLs verified against the Smart Home API's OpenAPI specification.
class ApiEndpoints {
  ApiEndpoints._();

  // Keep this without a trailing slash.
  static const String baseUrl =
      'http://127.0.0.1:8000'; //'https://smarthome-api.abdi-bako.workers.dev';
  static const String apiRoot = '$baseUrl/api/v1';
  static const String houses = '$apiRoot/houses';

  // /api/v1/houses/{house_id}/devices
  static String devices(String houseId) =>
      '$houses/${_segment(houseId)}/devices';

  // /api/v1/houses/{house_id}/devices/{device_id}
  // get: fetch device data ,
  // put: update device metadata ,
  // patch: update device state,
  // delete: remove device
  static String device(String houseId, String deviceId) =>
      '${devices(houseId)}/${_segment(deviceId)}';

  // /api/v1/houses/{house_id}/rooms/{room_id}/devices
  static String roomDevices(String houseId, String roomId) =>
      '$houses/${_segment(houseId)}/rooms/${_segment(roomId)}/devices';

  // Supply the backend's ws:// or wss:// URL when its protocol is defined.
  static const String? sensorWebSocket = null;
  // The notification transport will be updated when its WebSocket setup begins.
  static const String? notifications = null;

  static String _segment(String id) {
    if (id.trim().isEmpty) throw ArgumentError('API path ID is required');
    return Uri.encodeComponent(id);
  }
}
