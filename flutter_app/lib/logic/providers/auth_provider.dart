import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  UserModel? user;
  bool loading = false;
  bool bootstrapped = false;
  String? error;

  bool get isAuthenticated => user != null;

  Future<void> bootstrap() async {
    try {
      user = await _repository.fetchMe();
    } catch (_) {
      user = null;
    } finally {
      bootstrapped = true;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repository.login(identifier, password);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repository.register(
        username: username,
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
