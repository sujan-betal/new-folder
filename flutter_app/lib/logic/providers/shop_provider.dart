import 'package:flutter/foundation.dart';

import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';
import 'auth_provider.dart';

class ShopProvider extends ChangeNotifier {
  ShopProvider(this._repository, this._auth);

  final ShopRepository _repository;
  final AuthProvider _auth;

  List<ShopItemModel> items = [];
  bool loading = false;
  bool purchasing = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _repository.items();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> buy(ShopItemModel item) async {
    if (purchasing) return false;
    purchasing = true;
    error = null;
    notifyListeners();
    try {
      await _repository.purchase(item.id);
      await _auth.bootstrap(); // refresh coins/gems
      await load(); // refresh owned/equipped flags
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      purchasing = false;
      notifyListeners();
    }
  }
}

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository, this._auth);

  final ProfileRepository _repository;
  final AuthProvider _auth;

  List<HistoryEntry> history = [];
  bool loadingHistory = false;
  String? error;

  Future<void> loadHistory() async {
    loadingHistory = true;
    error = null;
    notifyListeners();
    try {
      history = await _repository.history();
    } catch (e) {
      error = e.toString();
    } finally {
      loadingHistory = false;
      notifyListeners();
    }
  }

  Future<bool> equipAvatar(String emoji) async {
    error = null;
    notifyListeners();
    try {
      await _repository.updateAvatar(emoji);
      await _auth.bootstrap();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
