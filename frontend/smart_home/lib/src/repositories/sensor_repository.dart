import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/models/sensors/sensor_reading.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/api_json.dart';

/// Draft reading contract; the published backend has no dedicated reading route.
class SensorRepository {
  const SensorRepository(
      {required this.apiClient, this.endpoint = ApiEndpoints.sensorData});

  final ApiClient apiClient;
  final String? endpoint;

  Future<List<SensorReading>> fetchSensorData({
    String? roomId,
    String? deviceId,
  }) async {
    final url = endpoint;
    if (url == null || url.trim().isEmpty) {
      throw UnsupportedError('No sensor-reading endpoint is published yet');
    }
    final response = await apiClient.get(
      url,
      queryParameters: {
        if (roomId != null) 'roomId': roomId,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
    return jsonObjects(response).map((json) {
      if (!json.containsKey('value')) {
        throw const FormatException('Sensor reading is missing value');
      }
      final value = json['value'];
      if (value != null &&
          value is! num &&
          value is! bool &&
          value is! String) {
        throw const FormatException('Unsupported sensor value');
      }
      if (value is num && !value.isFinite) {
        throw const FormatException('Sensor value must be finite');
      }
      return SensorReading(
        id: jsonString(json, 'id'),
        deviceId: jsonString(json, 'deviceId'),
        roomId: jsonString(json, 'roomId'),
        type: jsonString(json, 'type'),
        value: value,
        unit: jsonOptionalString(json, 'unit'),
        isOnline: jsonBool(json, 'isOnline'),
        recordedAt:
            json['recordedAt'] == null ? null : jsonDate(json, 'recordedAt'),
      );
    }).toList();
  }
}
