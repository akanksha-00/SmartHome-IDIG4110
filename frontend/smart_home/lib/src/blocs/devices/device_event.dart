import 'package:smart_home/src/models/devices/device_create_request.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

sealed class DeviceEvent {
  const DeviceEvent();
}

/// Startup requests reuse loaded data. An explicit refresh sets force to true.
final class DevicesRequested extends DeviceEvent {
  const DevicesRequested({this.force = false});
  final bool force;
}

/// Edited values only; DeviceBloc merges them into the full command state.
final class DeviceStateUpdateRequested extends DeviceEvent {
  DeviceStateUpdateRequested(
      {required this.id, required Map<String, Object?> updates})
      : updates = Map.unmodifiable(updates);
  final String id;
  final Map<String, Object?> updates;
}

final class DeviceAddRequested extends DeviceEvent {
  const DeviceAddRequested(this.device);
  final DeviceCreateRequest device;
}

final class DeviceRealtimeReceived extends DeviceEvent {
  const DeviceRealtimeReceived(this.message);
  final DeviceMessage message;
}

final class DeviceConnectionChanged extends DeviceEvent {
  const DeviceConnectionChanged(this.connection);
  final SocketConnectionState connection;
}

final class DeviceStreamFailed extends DeviceEvent {
  const DeviceStreamFailed(this.error);
  final Object error;
}

final class DeviceDiscovered extends DeviceEvent {
  const DeviceDiscovered(this.device, this.messages);
  final ApiDevice device;
  final List<DeviceMessage> messages;
}

final class DeviceAlertsRead extends DeviceEvent {
  const DeviceAlertsRead();
}
