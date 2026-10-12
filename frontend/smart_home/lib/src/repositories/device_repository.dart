import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/api_json.dart';

/// HTTP device operations for one house. DeviceBloc owns the loaded data/state.
class DeviceRepository {
  DeviceRepository({required this.apiClient, required this.houseId}) {
    if (houseId.trim().isEmpty) throw ArgumentError('House ID is required');
  }

  final ApiClient apiClient;
  final String houseId;

  Future<List<ApiDevice>> fetchDevices({String? roomId}) async {
    final endpoint = roomId == null
        ? ApiEndpoints.devices(houseId)
        : ApiEndpoints.roomDevices(houseId, roomId);
    return jsonObjects(await apiClient.get(endpoint)).map(_fromJson).toList();
  }

  /// Returns the backend's state and status without assuming capability names.
  Future<ApiDevice> fetchDevice(String id) async => _fromJson(
        jsonObject(await apiClient.get(ApiEndpoints.device(houseId, id))),
      );

  /// The API requires a supplied device ID; it does not generate one for us.
  Future<ApiDevice> addDevice({
    required String id,
    required String name,
    required String type,
    String? roomId,
    String? manufacturer,
    String? model,
    int? manufacturedYear,
    int? installedYear,
    String? installer,
    Map<String, DeviceCapability> capabilities = const {},
    Map<String, Object?> state = const {},
    Map<String, Object?> status = const {},
  }) async {
    if (id.trim().isEmpty || name.trim().isEmpty || type.trim().isEmpty) {
      throw ArgumentError('Device ID, name, and type are required');
    }
    if (roomId != null && roomId.trim().isEmpty) {
      throw ArgumentError('Room ID must be non-empty or null');
    }
    final response = await apiClient.post(ApiEndpoints.devices(houseId), {
      'id': id,
      'name': name.trim(),
      'type': type,
      if (roomId != null) 'room_id': roomId,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (manufacturedYear != null) 'manufactured_year': manufacturedYear,
      if (installedYear != null) 'installed_year': installedYear,
      if (installer != null) 'installer': installer,
      'capabilities':
          capabilities.map((key, value) => MapEntry(key, value.toJson())),
      'state': state,
      'status': status,
    });
    return _fromJson(jsonObject(response));
  }

  /// Keys and value scales must match the device's declared capabilities.
  /// The server validates capability types and bounds.
  Future<ApiDevice> updateDeviceMetadata({
    required String id,
    String? name,
    String? manufacturer,
    String? model,
    int? manufacturedYear,
    int? installedYear,
    String? installer,
  }) async {
    final response = await apiClient.put(ApiEndpoints.device(houseId, id), {
      if (name != null) 'name': name,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (manufacturedYear != null) 'manufactured_year': manufacturedYear,
      if (installedYear != null) 'installed_year': installedYear,
      if (installer != null) 'installer': installer,
    });

    return _fromJson(jsonObject(response));
  }

  Future<ApiDevice> updateDeviceStatus({
    required String id,
    required Map<String, Object?> updates,
  }) async {
    if (updates.isEmpty || updates.keys.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Supply at least one named capability update');
    }
    final response = await apiClient.patch(
      ApiEndpoints.device(houseId, id),
      [
        for (final entry in updates.entries)
          {'name': entry.key, 'value': entry.value}
      ],
    );

    return _fromJson(jsonObject(response));
  }

  /// Acknowledges MQTT publication only. Actual state arrives over WebSocket.
  Future<void> sendCommand({
    required String id,
    required Map<String, Object?> updates,
  }) async {
    if (updates.isEmpty || updates.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('Supply at least one named capability update');
    }
    final ack = jsonObject(await apiClient.post(
      ApiEndpoints.deviceCommand(houseId, id),
      {'state': updates},
    ));
    if (ack['house_id'] != houseId || ack['device_id'] != id) {
      throw const FormatException(
          'The command acknowledged a different device');
    }
  }

  Future<ApiDevice> removeDevice({
    required String id,
    required Map<String, Object?> updates,
  }) async {
    if (updates.isEmpty || updates.keys.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Supply at least one named capability update');
    }
    final response = await apiClient.delete(ApiEndpoints.device(houseId, id));

    return _fromJson(jsonObject(response));
  }

  ApiDevice _fromJson(Map<String, dynamic> json) {
    final capabilities = <String, DeviceCapability>{};
    final declared = json.containsKey('capabilities')
        ? jsonObject(json['capabilities'])
        : <String, dynamic>{};
    for (final entry in declared.entries) {
      final capability = jsonObject(entry.value);
      capabilities[entry.key] = DeviceCapability(
        type: jsonString(capability, 'type'),
        min: jsonOptionalNumber(capability, 'min'),
        max: jsonOptionalNumber(capability, 'max'),
      );
    }
    return ApiDevice(
      id: jsonString(json, 'id'),
      name: jsonString(json, 'name'),
      type: jsonString(json, 'type'),
      houseId: jsonString(json, 'house_id'),
      roomId: jsonOptionalString(json, 'room_id'),
      manufacturer: jsonOptionalString(json, 'manufacturer'),
      model: jsonOptionalString(json, 'model'),
      manufacturedYear: jsonOptionalInt(json, 'manufactured_year'),
      installedYear: jsonOptionalInt(json, 'installed_year'),
      installer: jsonOptionalString(json, 'installer'),
      capabilities: capabilities,
      state: json.containsKey('state') ? jsonObject(json['state']) : const {},
      status:
          json.containsKey('status') ? jsonObject(json['status']) : const {},
    );
  }
}
