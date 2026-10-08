import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:smart_home/src/blocs/devices/device_event.dart';
import 'package:smart_home/src/blocs/devices/device_state.dart';
import 'package:smart_home/src/models/devices/api_device.dart';
import 'package:smart_home/src/repositories/device_repository.dart';

export 'device_event.dart';
export 'device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({required this.repository}) : super(DeviceState()) {
    // Loads, creates and PATCHes share one queue so older responses cannot
    // overwrite newer changes, including changes to different capabilities.
    on<DeviceEvent>(_onEvent, transformer: sequential());
  }

  final DeviceRepository repository;
  final _pendingRequests = <Completer<Object?>>{};
  bool _closing = false;

  // Closing a sequential event queue must not wait for an HTTP timeout.
  Future<T> _request<T>(Future<T> request) {
    final completion = Completer<T>();
    _pendingRequests.add(completion);
    unawaited(request.then(
      (value) {
        if (!completion.isCompleted) completion.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    ));
    return completion.future
        .whenComplete(() => _pendingRequests.remove(completion));
  }

  @override
  Future<void> close() {
    _closing = true;
    for (final pending in _pendingRequests) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('DeviceBloc closed'));
      }
    }
    _pendingRequests.clear();
    return super.close();
  }

  Future<void> _onEvent(DeviceEvent event, Emitter<DeviceState> emit) async {
    if (_closing) return;
    switch (event) {
      case DevicesRequested():
        await _load(event, emit);
      case DeviceStateUpdateRequested():
        await _update(event, emit);
      case DeviceAddRequested():
        await _add(event, emit);
    }
  }

  Future<void> _load(DevicesRequested event, Emitter<DeviceState> emit) async {
    if (state.hasLoaded && !event.force) return;
    emit(state.copyWith(status: DeviceLoadStatus.loading, loadError: null));
    try {
      final devices = await _request(repository.fetchDevices());
      if (emit.isDone || _closing) return;
      emit(state.copyWith(
        devices: devices,
        status: DeviceLoadStatus.loaded,
        hasLoaded: true,
      ));
    } catch (error) {
      if (emit.isDone || _closing) return;
      emit(state.copyWith(status: DeviceLoadStatus.failed, loadError: error));
    }
  }

  Future<void> _update(
      DeviceStateUpdateRequested event, Emitter<DeviceState> emit) async {
    final index = state.devices.indexWhere((device) => device.id == event.id);
    if (index < 0 || event.updates.isEmpty) {
      emit(state.copyWith(
        updateError: StateError('Select a loaded device and a state update'),
        updateErrorRevision: state.updateErrorRevision + 1,
      ));
      return;
    }
    final previous = state.devices[index];
    emit(state.copyWith(
      devices: _replace(previous.withState(event.updates)),
      updatingDeviceId: event.id,
      updateError: null,
    ));
    try {
      final saved = await _request(
          repository.updateDeviceStatus(id: event.id, updates: event.updates));
      _checkResponse(saved, event.id);
      if (emit.isDone || _closing) return;
      emit(state.copyWith(devices: _replace(saved), updatingDeviceId: null));
    } catch (error) {
      if (emit.isDone || _closing) return;
      emit(state.copyWith(
        devices: _replace(previous),
        updatingDeviceId: null,
        updateError: error,
        updateErrorRevision: state.updateErrorRevision + 1,
      ));
    }
  }

  Future<void> _add(DeviceAddRequested event, Emitter<DeviceState> emit) async {
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
      emit(state.copyWith(
        devices: [...state.devices, saved],
        isAdding: false,
        lastAddedDeviceId: saved.id,
      ));
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
