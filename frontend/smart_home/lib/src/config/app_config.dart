class AppConfig {
  AppConfig._();

  static const String houseId = 'house-001';

  // Floor-plan mesh IDs differ from the IDs in the current house API.
  static const Map<String, String> deviceRoomIds = {
    'living': 'living-room',
    'bedroom1': 'bedroom',
  };

  static String deviceRoomId(String floorPlanRoomId) =>
      deviceRoomIds[floorPlanRoomId] ?? floorPlanRoomId;
}
