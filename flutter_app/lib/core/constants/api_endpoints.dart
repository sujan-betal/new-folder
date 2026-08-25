import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const String androidEmulatorBase = 'http://10.0.2.2:8000';
  static const String localBase = 'http://localhost:8000';

  static String get baseUrl => kIsWeb ? localBase : androidEmulatorBase;

  static String get api => '$baseUrl/api/v1';

  static String get register => '$api/auth/register';
  static String get login => '$api/auth/login';
  static String get me => '$api/auth/me';
  static String get guest => '$api/auth/guest';

  static String get leaderboard => '$api/users/leaderboard';

  static String get rooms => '$api/rooms';
  static String get roomsOpen => '$api/rooms/open';
  static String room(String code) => '$api/rooms/$code';
  static String get roomJoin => '$api/rooms/join';
  static String roomReady(String code) => '$api/rooms/$code/ready';
  static String roomLeave(String code) => '$api/rooms/$code/leave';

  static String get gameStart => '$api/games/start';
  static String get gameHistory => '$api/games/history';
  static String game(int id) => '$api/games/$id';
  static String gameRoll(int id) => '$api/games/$id/roll';
  static String gameMove(int id) => '$api/games/$id/move';

  static String get shopItems => '$api/shop/items';
  static String get shopPurchase => '$api/shop/purchase';

  static String get configApp => '$api/config/app';
}
