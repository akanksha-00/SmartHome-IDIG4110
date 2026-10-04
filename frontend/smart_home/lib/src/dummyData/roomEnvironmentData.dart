import 'package:smart_home/src/models/rooms/roomEnvironmentModel.dart';

const Map<String, RoomEnvironmentModel> roomEnvironments = {
  'living': RoomEnvironmentModel(
    airQuality: 'Good',
    temperature: 22.0,
    humidity: 45,
    occupancy: 0,
  ),
  'kitchen': RoomEnvironmentModel(
    airQuality: 'Okay',
    temperature: 24.0,
    humidity: 50,
    occupancy: 0,
  ),
  'bedroom1': RoomEnvironmentModel(
    airQuality: 'Good',
    temperature: 21.0,
    humidity: 42,
    occupancy: 0,
  ),
  'bathroom1': RoomEnvironmentModel(
    airQuality: 'Good',
    temperature: 23.0,
    humidity: 65,
    occupancy: 0,
  ),
};
