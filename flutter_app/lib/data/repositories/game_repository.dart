import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/room_model.dart';

class GameRepository {
  GameRepository(this._client);

  final ApiClient _client;

  Future<OnlineGameModel> start({required String mode, String? roomCode}) async {
    final data = await _client.post(
      ApiEndpoints.gameStart,
      jsonBody: {'mode': mode, if (roomCode != null) 'room_code': roomCode},
    );
    return OnlineGameModel.fromJson(_cast(data));
  }

  Future<OnlineGameModel> get(int gameId) async {
    final data = await _client.get(ApiEndpoints.game(gameId));
    return OnlineGameModel.fromJson(_cast(data));
  }

  /// Returns the full roll response including legal moves.
  Future<Map<String, dynamic>> roll(int gameId) async {
    final data = await _client.post(ApiEndpoints.gameRoll(gameId));
    return _cast(data);
  }

  Future<OnlineGameModel> move(int gameId, int tokenIndex) async {
    final data = await _client.post(
      ApiEndpoints.gameMove(gameId),
      jsonBody: {'token_index': tokenIndex},
    );
    return OnlineGameModel.fromJson(_cast(data));
  }

  Map<String, dynamic> _cast(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}
