import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:smart_home/src/blocs/devices/device_event.dart';
import 'package:smart_home/src/blocs/devices/device_state.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/models/notifications/device_alert.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

export 'device_event.dart';
export 'device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({
    required this.repository,
    this.realtime,
  }) : super(DeviceState(realtimeEnabled: realtime != null)) {
    // HTTP and live reports have separate queues: a slow HTTP response must
    // not hold up sensor readings or overwrite newer reported state.
    on<DevicesRequested>(_load, transformer: sequential());
    on<DeviceStateUpdateRequested>(_update, transformer: sequential());
    on<DeviceAddRequested>(_add, transformer: sequential());
    on<DeviceRealtimeReceived>(_live);
    on<DeviceDiscovered>(_discovered);
    on<DeviceConnectionChanged>((event, emit) {
      emit(state.copyWith(
          connection: event.connection,
          streamError: event.connection == SocketConnectionState.connected
              ? null
              : state.streamError));
      if (event.connection == SocketConnectionState.connected) {
        // GET may finish before the first handshake. The socket has no initial
        // snapshot or replay, so resync on every successful connection.
        add(const DevicesRequested(force: true));
      }
    });
    on<DeviceStreamFailed>(
        (event, emit) => emit(state.copyWith(streamError: event.error)));
    on<DeviceAlertsRead>((event, emit) => emit(state.copyWith(
          alerts: [
            for (final alert in state.alerts) alert.copyWith(isRead: true)
          ],
        )));
    if (realtime != null) {
      _messageSubscription = realtime!.messages.listen(
        (message) => add(DeviceRealtimeReceived(message)),
        onError: (Object error) => add(DeviceStreamFailed(error)),
      );
      _connectionSubscription = realtime!.connectionStates.listen(
        (connection) => add(DeviceConnectionChanged(connection)),
      );
      add(DeviceConnectionChanged(realtime!.connectionState));
      realtime!.start();
    }
  }

  final DeviceRepository repository;
  // Owned by the BLoC, alongside the house's device state.
  final HouseRealtimeRepository? realtime;
  StreamSubscription<DeviceMessage>? _messageSubscription;
  StreamSubscription<SocketConnectionState>? _connectionSubscription;
  final _pendingRequests = <Completer<Object?>>{};
  // Reports received during PATCH win over its returned device snapshot.
  final _pendingUpdates = <String, Map<String, Object?>>{};
  final _buffer = <String, Map<String, Object?>>{};
  final _unknown = <String, List<DeviceMessage>>{};
  final _createdDuringLoad = <ApiDevice>[];
  final _activeAlerts = <(String, String)>{};
  bool _loadingSnapshot = false;
  bool _closing = false;

  Future<T> _request<T>(Future<T> request) {
    final completion = Completer<T>();
    _pendingRequests.add(completion);
    unawaited(request.then((value) {
      if (!completion.isCompleted) completion.complete(value);
    }, onError: (Object error, StackTrace stack) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    }));
    return completion.future
        .whenComplete(() => _pendingRequests.remove(completion));
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _messageSubscription?.cancel();
    await _connectionSubscription?.cancel();
    for (final pending in _pendingRequests.toList()) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('DeviceBloc closed'));
      }
    }
    _pendingRequests.clear();
    await realtime?.dispose();
    await super.close();
  }

  Future<void> _load(DevicesRequested event, Emitter<DeviceState> emit) async {
    if (_closing || (state.hasLoaded && !event.force)) return;
    _loadingSnapshot = true;
    _createdDuringLoad.clear();
    emit(state.copyWith(status: DeviceLoadStatus.loading, loadError: null));
    try {
      final devices = await _request(repository.fetchDevices());
      if (emit.isDone || _closing) return;
      if (devices.any((device) => device.houseId != repository.houseId) ||
          devices.map((device) => device.id).toSet().length != devices.length) {
        throw const FormatException('Invalid house device snapshot');
      }
      final byId = {for (final device in devices) device.id: device};
      for (final device in _createdDuringLoad) {
        byId[device.id] = device;
      }
      // Reports received during GET take precedence over its snapshot.
      final unknown = <DeviceMessage>[];
      for (final entry in _buffer.entries) {
        final device = byId[entry.key];
        if (device != null) {
          byId[device.id] = device.withState(entry.value);
        } else {
          unknown.add(DeviceMessage(deviceId: entry.key, updates: entry.value));
        }
      }
      _buffer.clear();
      emit(state.copyWith(
          devices: byId.values.toList(),
          status: DeviceLoadStatus.loaded,
          hasLoaded: true,
          loadError: null,
          pendingDeviceIds: _pendingUpdates.keys.toSet()));
      for (final message in unknown) {
        add(DeviceRealtimeReceived(message));
      }
    } catch (error) {
      if (emit.isDone || _closing) return;
      emit(state.copyWith(status: DeviceLoadStatus.failed, loadError: error));
    } finally {
      _loadingSnapshot = false;
      _createdDuringLoad.clear();
      if (!_closing && state.hasLoaded) {
        final buffered = _buffer.entries
            .map((entry) =>
                DeviceMessage(deviceId: entry.key, updates: entry.value))
            .toList();
        _buffer.clear();
        for (final message in buffered) {
          add(DeviceRealtimeReceived(message));
        }
      }
    }
  }

  Future<void> _update(
      DeviceStateUpdateRequested event, Emitter<DeviceState> emit) async {
    if (_closing) return;
    final device = state.devices.where((d) => d.id == event.id).firstOrNull;
    if (device == null || event.updates.isEmpty) {
      _updateError(
          StateError('Select a loaded device and a state update'), emit);
      return;
    }
    if (_pendingUpdates.containsKey(event.id)) return;
    if (_loadingSnapshot) {
      _updateError(
          StateError('Wait for device data to finish refreshing'), emit);
      return;
    }
    final reports = <String, Object?>{};
    _pendingUpdates[event.id] = reports;
    emit(state.copyWith(
        pendingDeviceIds: _pendingUpdates.keys.toSet(), updateError: null));
    try {
      final response = await _request(
          repository.updateDeviceStatus(id: event.id, updates: event.updates));
      if (emit.isDone || _closing) return;
      _checkResponse(response, event.id);
      final saved = response.withState(reports);
      _pendingUpdates.remove(event.id);
      // A reconnect GET can run alongside PATCH. Its older snapshot must not
      // undo the state that the backend just saved.
      if (_loadingSnapshot) {
        _buffer.putIfAbsent(event.id, () => {}).addAll(saved.state);
      }
      emit(state.copyWith(
          devices: _replace(saved),
          pendingDeviceIds: _pendingUpdates.keys.toSet()));
    } catch (error) {
      if (emit.isDone || _closing) return;
      _pendingUpdates.remove(event.id);
      _updateError(error, emit);
    }
  }

  void _updateError(Object error, Emitter<DeviceState> emit) =>
      emit(state.copyWith(
        pendingDeviceIds: _pendingUpdates.keys.toSet(),
        updateError: error,
        updateErrorRevision: state.updateErrorRevision + 1,
      ));

  void _live(DeviceRealtimeReceived event, Emitter<DeviceState> emit) {
    if (_closing) return;
    final message = event.message;
    final buffering = _loadingSnapshot || !state.hasLoaded;
    if (buffering) {
      // Coalesce capability values while loading; alerts remain immediate.
      _buffer.putIfAbsent(message.deviceId, () => {}).addAll(message.updates);
    }
    final device =
        state.devices.where((d) => d.id == message.deviceId).firstOrNull;
    var devices = state.devices;
    if (device != null) {
      _unknown[device.id]?.add(message);
      final changed = device.withState(message.updates);
      devices = _replace(changed);
      _pendingUpdates[device.id]?.addAll(message.updates);
    } else if (!buffering) {
      final pending = _unknown[message.deviceId];
      if (pending != null) {
        pending.add(message);
      } else {
        _unknown[message.deviceId] = [message];
        unawaited(_fetchUnknown(message.deviceId));
      }
    }
    final alerts = _alertsFor(message, device);
    emit(state.copyWith(
        devices: devices,
        pendingDeviceIds: _pendingUpdates.keys.toSet(),
        streamError: null,
        alerts: alerts,
        alertRevision:
            alerts.isNotEmpty && alerts.first.sequence > state.alertRevision
                ? alerts.first.sequence
                : state.alertRevision));
  }

  List<DeviceAlert> _alertsFor(DeviceMessage message, ApiDevice? device) {
    final alerts = state.alerts;
    final event = message.event;
    if (event == null) return alerts;
    final key = (message.deviceId, event);
    if (!message.alert) {
      _activeAlerts.remove(key);
      return [
        for (final alert in alerts)
          if ((alert.deviceId, alert.event) == key)
            alert.copyWith(isActive: false)
          else
            alert
      ];
    }
    if (!_activeAlerts.add(key)) return alerts;
    final text = message.notificationMessage;
    return [
      DeviceAlert(
        sequence: state.alertRevision + 1,
        deviceId: message.deviceId,
        event: event,
        value: message.value,
        message: text != null && text.trim().isNotEmpty
            ? text
            : '${device?.name ?? message.deviceId}: $event alert',
      ),
      ...alerts.take(49)
    ];
  }

  Future<void> _fetchUnknown(String id) async {
    try {
      final device = await _request(repository.fetchDevice(id));
      _checkResponse(device, id);
      if (!_closing) {
        final messages = _unknown[id] ?? [];
        add(DeviceDiscovered(device, messages));
      }
    } catch (error) {
      _unknown.remove(id);
      if (!_closing) add(DeviceStreamFailed(error));
    }
  }

  void _discovered(DeviceDiscovered event, Emitter<DeviceState> emit) {
    if (_closing) return;
    _unknown.remove(event.device.id);
    var device =
        state.devices.where((d) => d.id == event.device.id).firstOrNull ??
            event.device;
    // Merge synchronously: replaying old messages as new events could overtake
    // a fresh report arriving immediately after this metadata response.
    for (final message in event.messages) {
      device = device.withState(message.updates);
    }
    if (_loadingSnapshot) _createdDuringLoad.add(device);
    final exists = state.devices.any((d) => d.id == device.id);
    emit(state.copyWith(
        devices: exists ? _replace(device) : [...state.devices, device]));
  }

  Future<void> _add(DeviceAddRequested event, Emitter<DeviceState> emit) async {
    if (_closing) return;
    emit(state.copyWith(
        isAdding: true, addError: null, lastAddedDeviceId: null));
    try {
      final draft = event.device;
      if (state.devices.any((device) => device.id == draft.id)) {
        throw ArgumentError('A device with this ID already exists');
      }
      final saved = await _request(repository.addDevice(
        id: draft.id,
        name: draft.name,
        type: draft.type,
        roomId: draft.roomId,
        capabilities: draft.capabilities,
        state: draft.state,
      ));
      _checkResponse(saved, draft.id);
      if (emit.isDone || _closing) return;
      final existing =
          state.devices.where((device) => device.id == saved.id).firstOrNull;
      if (_loadingSnapshot) _createdDuringLoad.add(existing ?? saved);
      emit(state.copyWith(
          devices: existing != null ? state.devices : [...state.devices, saved],
          isAdding: false,
          lastAddedDeviceId: saved.id));
    } catch (error) {
      if (emit.isDone || _closing) return;
      emit(state.copyWith(isAdding: false, addError: error));
    }
  }

  List<ApiDevice> _replace(ApiDevice changed) => [
        for (final device in state.devices)
          device.id == changed.id ? changed : device,
      ];

  void _checkResponse(ApiDevice device, String expectedId) {
    if (device.id != expectedId || device.houseId != repository.houseId) {
      throw const FormatException('The API returned an unexpected device');
    }
  }
}
