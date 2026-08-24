class UserModel {
  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.coins,
    required this.gems,
    required this.wins,
    required this.losses,
    required this.level,
    required this.xp,
  });

  final int id;
  final String username;
  final String email;
  final String avatar;
  final int coins;
  final int gems;
  final int wins;
  final int losses;
  final int level;
  final int xp;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '\u{1F3B2}',
        coins: json['coins'] as int? ?? 0,
        gems: json['gems'] as int? ?? 0,
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        xp: json['xp'] as int? ?? 0,
      );
}
