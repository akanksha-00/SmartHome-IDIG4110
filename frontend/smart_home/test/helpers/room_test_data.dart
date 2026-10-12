import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/room_repository.dart';

Map<String, Object?> roomJson({
  String id = 'living-room',
  String name = 'Living Room',
}) =>
    {
      'id': id,
      'house_id': AppConfig.houseId,
      'name': name,
    };

RoomBloc testRoomBloc(Future<http.Response> Function(http.Request) handler) {
  final client = ApiClient(client: MockClient(handler));
  final bloc = RoomBloc(
      repository: RoomRepository(
    apiClient: client,
    houseId: AppConfig.houseId,
  ));
  addTearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    client.close();
  });
  return bloc;
}

Future<RoomState> waitForRoomState(
        RoomBloc bloc, bool Function(RoomState) matches) =>
    bloc.stream.firstWhere(matches).timeout(const Duration(seconds: 3));

Future<void> loadRooms(RoomBloc bloc, {bool force = false}) async {
  final loaded =
      waitForRoomState(bloc, (state) => state.status == RoomLoadStatus.loaded);
  bloc.add(RoomsRequested(force: force));
  await loaded;
}
