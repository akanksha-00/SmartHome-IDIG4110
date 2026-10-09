import 'package:smart_home/src/models/rooms/api_room.dart';

/// Frontend-only links from API room IDs to this house's Blender asset.
/// Room names and the available room list still come from the API.
class FloorPlanBindings {
  FloorPlanBindings._();

  static const _houseObjects = {
    'house-001': {
      'living-room': 'livingRoom',
      'kitchen': 'kitchen',
      'bedroom': 'bedroom1',
      'bathroom1': 'bathroom1',
    },
  };

  static String? objectNameFor(ApiRoom room) =>
      _houseObjects[room.houseId]?[room.id];
}
