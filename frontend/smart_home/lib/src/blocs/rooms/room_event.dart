sealed class RoomEvent {
  const RoomEvent();
}

class RoomsRequested extends RoomEvent {
  const RoomsRequested({this.force = false});
  final bool force;
}

class RoomSelected extends RoomEvent {
  const RoomSelected(this.id);
  final String id;
}
