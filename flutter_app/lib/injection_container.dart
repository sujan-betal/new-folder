import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'logic/providers/auth_provider.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<TokenStorage>(() => TokenStorage(prefs));
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(sl(), sl()));
  sl.registerFactory<AuthProvider>(() => AuthProvider(sl())..bootstrap());
}
