import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/models/rooms/api_room.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/api_json.dart';

/// HTTP room reads for one house. RoomBloc owns the fetched list and selection.
class RoomRepository {
  RoomRepository({required this.apiClient, required this.houseId}) {
    if (houseId.trim().isEmpty) throw ArgumentError('House ID is required');
  }

  final ApiClient apiClient;
  final String houseId;

  Future<List<ApiRoom>> fetchRooms() async {
    final records =
        jsonObjects(await apiClient.get(ApiEndpoints.rooms(houseId)));
    final ids = <String>{};
    final rooms = <ApiRoom>[];
    for (final record in records) {
      final id = jsonString(record, 'id');
      final returnedHouseId = jsonString(record, 'house_id');
      if (returnedHouseId != houseId || !ids.add(id)) {
        throw const FormatException('The API returned an unexpected room');
      }
      rooms.add(ApiRoom(
        id: id,
        houseId: returnedHouseId,
        name: jsonString(record, 'name'),
      ));
    }
    return rooms;
  }
}
