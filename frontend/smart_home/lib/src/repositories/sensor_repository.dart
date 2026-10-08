import 'package:smart_home/src/models/sensors/sensor_reading.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

/// An adapter for the eventual backend message format. Return an empty iterable
/// for unrelated events, one reading for an update, or many for a snapshot.
typedef SensorMessageDecoder = Iterable<SensorReading> Function(
  Map<String, dynamic> message,
);

class SensorRepository {
  const SensorRepository({
    required this.socket,
    required this.decodeMessage,
  });

  final WebSocketService socket;
  final SensorMessageDecoder decodeMessage;

  /// All listeners share the injected socket; filtering opens no new connections.
  Stream<SensorReading> watchSensorData({String? roomId, String? deviceId}) =>
      socket.messages.expand(decodeMessage).where((reading) =>
          (roomId == null || reading.roomId == roomId) &&
          (deviceId == null || reading.deviceId == deviceId));

  Future<void> connect() => socket.connect();

  // The session owner disposes the shared socket, not an individual consumer.
}
