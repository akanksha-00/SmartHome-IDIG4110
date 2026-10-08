import 'package:smart_home/src/models/devices/api_device.dart';

enum DeviceLoadStatus { initial, loading, loaded, failed }

const _keep = Object();

/// The device list and all request state belong to the BLoC.
class DeviceState {
  DeviceState({
    List<ApiDevice> devices = const [],
    this.status = DeviceLoadStatus.initial,
    this.hasLoaded = false,
    this.loadError,
    this.updatingDeviceId,
    this.updateError,
    this.updateErrorRevision = 0,
    this.isAdding = false,
    this.addError,
    this.lastAddedDeviceId,
  }) : devices = List.unmodifiable(devices);

  final List<ApiDevice> devices;
  final DeviceLoadStatus status;
  final bool hasLoaded;
  final Object? loadError;
  final String? updatingDeviceId;
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
    Object? updatingDeviceId = _keep,
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
        updatingDeviceId: identical(updatingDeviceId, _keep)
            ? this.updatingDeviceId
            : updatingDeviceId as String?,
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
