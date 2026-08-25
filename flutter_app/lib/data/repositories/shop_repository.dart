import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/shop_model.dart';

class ShopRepository {
  ShopRepository(this._client);

  final ApiClient _client;

  Future<List<ShopItemModel>> items() async {
    final data = await _client.get(ApiEndpoints.shopItems);
    return ((data as List?) ?? const [])
        .map((e) => ShopItemModel.fromJson(_cast(e)))
        .toList();
  }

  /// Returns the refreshed user payload from the purchase response.
  Future<Map<String, dynamic>> purchase(String itemId) async {
    final data = await _client.post(
      ApiEndpoints.shopPurchase,
      jsonBody: {'item_id': itemId},
    );
    return _cast(data);
  }

  Map<String, dynamic> _cast(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}

class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Future<List<HistoryEntry>> history() async {
    final data = await _client.get(ApiEndpoints.gameHistory);
    return ((data as List?) ?? const [])
        .map((e) => HistoryEntry.fromJson(_cast(e)))
        .toList();
  }

  Future<void> updateAvatar(String emoji) async {
    await _client.patch(ApiEndpoints.me, jsonBody: {'avatar': emoji});
  }

  Map<String, dynamic> _cast(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}

class ConfigRepository {
  ConfigRepository(this._client);

  final ApiClient _client;

  Future<AppConfigModel> appConfig() async {
    final data = await _client.get(ApiEndpoints.configApp);
    return AppConfigModel.fromJson(_cast(data));
  }

  Map<String, dynamic> _cast(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
}
