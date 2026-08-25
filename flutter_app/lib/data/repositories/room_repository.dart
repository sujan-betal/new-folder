import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/room_model.dart';

class RoomRepository {
  RoomRepository(this._client);

  final ApiClient _client;

  Future<RoomModel> create({required String name, required int maxPlayers}) async {
    final data = await _client.post(
      ApiEndpoints.rooms,
      jsonBody: {'name': name, 'max_players': maxPlayers},
    );
    return RoomModel.fromJson(_cast(data));
  }

  Future<RoomModel> join(String code) async {
    final data = await _client.post(
      ApiEndpoints.roomJoin,
      jsonBody: {'code': code.trim().toUpperCase()},
    );
    return RoomModel.fromJson(_cast(data));
  }

  Future<List<RoomModel>> openRooms() async {
    final data = await _client.get(ApiEndpoints.roomsOpen);
    return ((data as List?) ?? const [])
        .map((e) => RoomModel.fromJson(_cast(e)))
        .toList();
  }

  Future<RoomModel> get(String code) async {
    final data = await _client.get(ApiEndpoints.room(code.toUpperCase()));
    return RoomModel.fromJson(_cast(data));
  }

  Future<RoomModel> toggleReady(String code) async {
    final data = await _client.post(ApiEndpoints.roomReady(code.toUpperCase()));
    return RoomModel.fromJson(_cast(data));
  }

  Future<void> leave(String code) async {
    await _client.post(ApiEndpoints.roomLeave(code.toUpperCase()));
  }

  Map<String, dynamic> _cast(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}
