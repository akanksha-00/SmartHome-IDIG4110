import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:smart_home/src/blocs/rooms/room_event.dart';
import 'package:smart_home/src/blocs/rooms/room_state.dart';
import 'package:smart_home/src/models/rooms/api_room.dart';
import 'package:smart_home/src/repositories/room_repository.dart';

export 'room_event.dart';
export 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  RoomBloc({required this.repository}) : super(RoomState()) {
    // A selection made during a refresh is applied after the fresh room list.
    on<RoomEvent>(_onEvent, transformer: sequential());
  }

  final RoomRepository repository;
  Completer<List<ApiRoom>>? _pendingLoad;
  bool _closing = false;

  Future<void> _onEvent(RoomEvent event, Emitter<RoomState> emit) async {
    if (_closing) return;
    switch (event) {
      case RoomsRequested():
        await _load(event, emit);
      case RoomSelected():
        if (event.id != state.selectedRoomId &&
            state.rooms.any((room) => room.id == event.id)) {
          emit(state.copyWith(selectedRoomId: event.id));
        }
    }
  }

  Future<List<ApiRoom>> _fetchRooms() {
    final completion = Completer<List<ApiRoom>>();
    _pendingLoad = completion;
    unawaited(repository.fetchRooms().then(
      (rooms) {
        if (!completion.isCompleted) completion.complete(rooms);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    ));
    return completion.future.whenComplete(() => _pendingLoad = null);
  }

  Future<void> _load(RoomsRequested event, Emitter<RoomState> emit) async {
    if (_closing || (state.hasLoaded && !event.force)) return;
    emit(state.copyWith(status: RoomLoadStatus.loading, loadError: null));
    try {
      final rooms = await _fetchRooms();
      if (emit.isDone || _closing) return;
      final previousSelection = state.selectedRoomId;
      final selectedId = rooms.any((room) => room.id == previousSelection)
          ? previousSelection
          : rooms.isEmpty
              ? null
              : rooms.first.id;
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: selectedId,
        status: RoomLoadStatus.loaded,
        hasLoaded: true,
      ));
    } catch (error) {
      if (emit.isDone || _closing) return;
      emit(state.copyWith(status: RoomLoadStatus.failed, loadError: error));
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    final pending = _pendingLoad;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('RoomBloc closed'));
    }
    return super.close();
  }
}
