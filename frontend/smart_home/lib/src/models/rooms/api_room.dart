/// Room identity from the backend's room schema.
class ApiRoom {
  const ApiRoom({
    required this.id,
    required this.houseId,
    required this.name,
  });

  final String id;
  final String houseId;
  final String name;
}
