class RoomEnvironmentModel {
  const RoomEnvironmentModel({
    required this.airQuality,
    required this.temperature,
    required this.humidity,
    required this.occupancy,
  });

  final String airQuality;
  final double temperature;
  final int humidity;
  final int occupancy;
}
