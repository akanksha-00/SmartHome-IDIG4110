import 'package:smart_home/src/models/rooms/api_room.dart';

enum RoomLoadStatus { initial, loading, loaded, failed }

const _keep = Object();

class RoomState {
  RoomState({
    List<ApiRoom> rooms = const [],
    this.status = RoomLoadStatus.initial,
    this.hasLoaded = false,
    this.loadError,
    this.selectedRoomId,
  }) : rooms = List.unmodifiable(rooms);

  final List<ApiRoom> rooms;
  final RoomLoadStatus status;
  final bool hasLoaded;
  final Object? loadError;
  final String? selectedRoomId;

  ApiRoom? get selectedRoom {
    for (final room in rooms) {
      if (room.id == selectedRoomId) return room;
    }
    return null;
  }

  RoomState copyWith({
    List<ApiRoom>? rooms,
    RoomLoadStatus? status,
    bool? hasLoaded,
    Object? loadError = _keep,
    Object? selectedRoomId = _keep,
  }) =>
      RoomState(
        rooms: rooms ?? this.rooms,
        status: status ?? this.status,
        hasLoaded: hasLoaded ?? this.hasLoaded,
        loadError: identical(loadError, _keep) ? this.loadError : loadError,
        selectedRoomId: identical(selectedRoomId, _keep)
            ? this.selectedRoomId
            : selectedRoomId as String?,
      );
}
