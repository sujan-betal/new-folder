class RoomModel {
  RoomModel({
    required this.code,
    required this.name,
    required this.hostId,
    required this.maxPlayers,
    required this.status,
    required this.players,
  });

  final String code;
  final String name;
  final int hostId;
  final int maxPlayers;
  final String status;
  final List<RoomPlayerModel> players;

  bool get isFull => players.length >= maxPlayers;

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? 'Room').toString(),
        hostId: (json['host_id'] as num?)?.toInt() ?? 0,
        maxPlayers: (json['max_players'] as num?)?.toInt() ?? 4,
        status: (json['status'] ?? 'waiting').toString(),
        players: ((json['players'] as List?) ?? const [])
            .map((e) => RoomPlayerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class RoomPlayerModel {
  RoomPlayerModel({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.color,
    required this.seat,
    required this.isReady,
  });

  final int userId;
  final String username;
  final String avatar;
  final String? color;
  final int seat;
  final bool isReady;

  factory RoomPlayerModel.fromJson(Map<String, dynamic> json) =>
      RoomPlayerModel(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        username: (json['username'] ?? '?').toString(),
        avatar: (json['avatar'] ?? '').toString(),
        color: json['color']?.toString(),
        seat: (json['seat'] as num?)?.toInt() ?? 0,
        isReady: json['is_ready'] == true,
      );
}

class OnlineGameModel {
  OnlineGameModel({
    required this.id,
    required this.mode,
    required this.status,
    required this.currentTurn,
    required this.tokens,
    required this.participants,
    this.diceValue,
    this.winnerId,
  });

  final int id;
  final String mode;
  final String status;
  final String currentTurn;
  final Map<String, List<int>> tokens;
  final List<Map<String, dynamic>> participants;
  final int? diceValue;
  final int? winnerId;

  bool get isActive => status == 'active';

  factory OnlineGameModel.fromJson(Map<String, dynamic> json) {
    final tokensRaw = (json['state']?['tokens'] as Map?) ?? const {};
    final participantsRaw = ((json['state']?['participants'] as List?) ??
            const [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return OnlineGameModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mode: (json['mode'] ?? 'online').toString(),
      status: (json['status'] ?? 'active').toString(),
      currentTurn: (json['current_turn'] ?? 'red').toString(),
      diceValue: (json['dice_value'] as num?)?.toInt(),
      winnerId: (json['winner_id'] as num?)?.toInt(),
      tokens: tokensRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List).map((e) => (e as num).toInt()).toList(),
        ),
      ),
      participants: participantsRaw,
    );
  }
}
