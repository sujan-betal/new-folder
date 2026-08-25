class ShopItemModel {
  ShopItemModel({
    required this.id,
    required this.type,
    required this.emoji,
    required this.label,
    required this.priceCoins,
    required this.priceGems,
    required this.owned,
    required this.equipped,
  });

  final String id;
  final String type;
  final String emoji;
  final String label;
  final int priceCoins;
  final int priceGems;
  final bool owned;
  final bool equipped;

  bool get isFree => priceCoins == 0 && priceGems == 0;

  factory ShopItemModel.fromJson(Map<String, dynamic> json) => ShopItemModel(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? 'avatar').toString(),
        emoji: (json['emoji'] ?? '\u{1F3B2}').toString(),
        label: (json['label'] ?? '').toString(),
        priceCoins: (json['price_coins'] as num?)?.toInt() ?? 0,
        priceGems: (json['price_gems'] as num?)?.toInt() ?? 0,
        owned: json['owned'] == true,
        equipped: json['equipped'] == true,
      );
}

class HistoryEntry {
  HistoryEntry({
    required this.gameId,
    required this.color,
    required this.placement,
    required this.coinsEarned,
    required this.xpEarned,
    required this.playedAt,
  });

  final int gameId;
  final String color;
  final int placement;
  final int coinsEarned;
  final int xpEarned;
  final String playedAt;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        gameId: (json['game_id'] as num?)?.toInt() ?? 0,
        color: (json['color'] ?? 'red').toString(),
        placement: (json['placement'] as num?)?.toInt() ?? 0,
        coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
        xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
        playedAt: (json['played_at'] ?? '').toString(),
      );
}

class AppConfigModel {
  AppConfigModel({
    required this.announcement,
    required this.maintenanceMode,
    required this.dailyBonusCoins,
  });

  final String announcement;
  final bool maintenanceMode;
  final int dailyBonusCoins;

  factory AppConfigModel.fromJson(Map<String, dynamic> json) => AppConfigModel(
        announcement: (json['announcement'] ?? '').toString(),
        maintenanceMode: json['maintenance_mode'] == true,
        dailyBonusCoins: (json['daily_bonus_coins'] as num?)?.toInt() ?? 0,
      );
}
