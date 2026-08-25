class GameModel {
  final int id;
  final int? roomId;
  final String mode;
  final String status;
  final String currentTurn;
  final int? diceValue;
  final int? winnerId;
  final Map<String, List<int>> tokens;
  final List<Map<String, dynamic>> participants;

  GameModel({
    required this.id,
    this.roomId,
    required this.mode,
    required this.status,
    required this.currentTurn,
    this.diceValue,
    this.winnerId,
    required this.tokens,
    required this.participants,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    // Parse tokens map: Map<String, dynamic> -> Map<String, List<int>>
    final tokensMap = <String, List<int>>{};
    final state = json['state'] as Map<String, dynamic>? ?? {};
    final rawTokens = state['tokens'] as Map<String, dynamic>? ?? {};
    
    rawTokens.forEach((key, value) {
      if (value is List) {
        tokensMap[key] = value.map((e) => (e as num).toInt()).toList();
      }
    });

    final rawParticipants = state['participants'] as List<dynamic>? ?? [];
    final participantsList = rawParticipants
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return GameModel(
      id: json['id'] as int,
      roomId: json['room_id'] as int?,
      mode: json['mode'] as String,
      status: json['status'] as String,
      currentTurn: json['current_turn'] as String,
      diceValue: json['dice_value'] as int?,
      winnerId: json['winner_id'] as int?,
      tokens: tokensMap,
      participants: participantsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'mode': mode,
      'status': status,
      'current_turn': currentTurn,
      'dice_value': diceValue,
      'winner_id': winnerId,
      'state': {
        'tokens': tokens.map((key, value) => MapEntry(key, value)),
        'participants': participants,
      },
    };
  }
}
