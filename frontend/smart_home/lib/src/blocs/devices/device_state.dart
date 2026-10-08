import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/notifications/device_alert.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

enum DeviceLoadStatus { initial, loading, loaded, failed }

const _keep = Object();

/// The device list and all request state belong to the BLoC.
class DeviceState {
  DeviceState({
    List<ApiDevice> devices = const [],
    this.status = DeviceLoadStatus.initial,
    this.hasLoaded = false,
    this.loadError,
    Set<String> pendingDeviceIds = const {},
    this.connection = SocketConnectionState.disconnected,
    this.realtimeEnabled = false,
    this.streamError,
    List<DeviceAlert> alerts = const [],
    this.alertRevision = 0,
    this.updateError,
    this.updateErrorRevision = 0,
    this.isAdding = false,
    this.addError,
    this.lastAddedDeviceId,
  })  : devices = List.unmodifiable(devices),
        pendingDeviceIds = Set.unmodifiable(pendingDeviceIds),
        alerts = List.unmodifiable(alerts);

  final List<ApiDevice> devices;
  final DeviceLoadStatus status;
  final bool hasLoaded;
  final Object? loadError;
  final Set<String> pendingDeviceIds;
  String? get updatingDeviceId => pendingDeviceIds.firstOrNull;
  final SocketConnectionState connection;
  final bool realtimeEnabled;
  final Object? streamError;
  final List<DeviceAlert> alerts;
  final int alertRevision;
  int get unreadAlertCount => alerts.where((alert) => !alert.isRead).length;
  final Object? updateError;
  final int updateErrorRevision;
  final bool isAdding;
  final Object? addError;
  final String? lastAddedDeviceId;

  DeviceState copyWith({
    List<ApiDevice>? devices,
    DeviceLoadStatus? status,
    bool? hasLoaded,
    Object? loadError = _keep,
    Set<String>? pendingDeviceIds,
    SocketConnectionState? connection,
    bool? realtimeEnabled,
    Object? streamError = _keep,
    List<DeviceAlert>? alerts,
    int? alertRevision,
    Object? updateError = _keep,
    int? updateErrorRevision,
    bool? isAdding,
    Object? addError = _keep,
    Object? lastAddedDeviceId = _keep,
  }) =>
      DeviceState(
        devices: devices ?? this.devices,
        status: status ?? this.status,
        hasLoaded: hasLoaded ?? this.hasLoaded,
        loadError: identical(loadError, _keep) ? this.loadError : loadError,
        pendingDeviceIds: pendingDeviceIds ?? this.pendingDeviceIds,
        connection: connection ?? this.connection,
        realtimeEnabled: realtimeEnabled ?? this.realtimeEnabled,
        streamError:
            identical(streamError, _keep) ? this.streamError : streamError,
        alerts: alerts ?? this.alerts,
        alertRevision: alertRevision ?? this.alertRevision,
        updateError:
            identical(updateError, _keep) ? this.updateError : updateError,
        updateErrorRevision: updateErrorRevision ?? this.updateErrorRevision,
        isAdding: isAdding ?? this.isAdding,
        addError: identical(addError, _keep) ? this.addError : addError,
        lastAddedDeviceId: identical(lastAddedDeviceId, _keep)
            ? this.lastAddedDeviceId
            : lastAddedDeviceId as String?,
      );
}
