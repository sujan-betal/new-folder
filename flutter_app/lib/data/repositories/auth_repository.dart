import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/token_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final TokenStorage _storage;

  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      ApiEndpoints.register,
      jsonBody: {'username': username, 'email': email, 'password': password},
    );
    return UserModel.fromJson(_cast(data));
  }

  Future<UserModel> login(String identifier, String password) async {
    final data = await _client.post(
      ApiEndpoints.login,
      jsonBody: {'identifier': identifier, 'password': password},
    );
    final token = ((data as Map)['access_token']) as String;
    await _storage.write(token);
    return fetchMe();
  }

  Future<UserModel> fetchMe() async {
    final data = await _client.get(ApiEndpoints.me);
    return UserModel.fromJson(_cast(data));
  }

  Future<void> logout() => _storage.clear();

  Map<String, dynamic> _cast(dynamic data) => Map<String, dynamic>.from(data as Map);
}
