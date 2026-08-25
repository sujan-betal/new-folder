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

  Future<UserModel> loginAsGuest() async {
    final data = await _client.post(ApiEndpoints.guest) as Map;
    final token = data['access_token'] as String;
    await _storage.write(token);
    return UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<UserModel> loginWithSocialToken({
    required String provider,
    required String token,
  }) async {
    assert(provider == 'google' || provider == 'facebook');
    final data = await _client.post(
      '$ApiEndpoints.api/auth/$provider',
      jsonBody: {'token': token},
    ) as Map;
    final accessToken = data['access_token'] as String;
    await _storage.write(accessToken);
    return UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<UserModel> fetchMe() async {
    final data = await _client.get(ApiEndpoints.me);
    return UserModel.fromJson(_cast(data));
  }

  Future<void> logout() => _storage.clear();

  Map<String, dynamic> _cast(dynamic data) => Map<String, dynamic>.from(data as Map);
}
