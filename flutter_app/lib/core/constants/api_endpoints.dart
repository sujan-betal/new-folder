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
  static String get leaderboard => '$api/users/leaderboard';
  static String get rooms => '$api/rooms';
  static String get gameStart => '$api/games/start';
}
