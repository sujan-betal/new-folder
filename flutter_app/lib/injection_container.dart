import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/api_client.dart';
import 'core/network/google_sign_in_service.dart';
import 'core/network/token_storage.dart';
import 'core/sound/sound_manager.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/game_repository.dart';
import 'data/repositories/room_repository.dart';
import 'data/repositories/shop_repository.dart';
import 'logic/providers/auth_provider.dart';
import 'logic/providers/game_online_provider.dart';
import 'logic/providers/room_provider.dart';
import 'logic/providers/shop_provider.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  await SoundManager.instance.init(prefs);
  sl.registerLazySingleton<TokenStorage>(() => TokenStorage(prefs));
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(sl(), sl()));
  sl.registerLazySingleton<GameRepository>(() => GameRepository(sl()));
  sl.registerLazySingleton<RoomRepository>(() => RoomRepository(sl()));
  sl.registerLazySingleton<ShopRepository>(() => ShopRepository(sl()));
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepository(sl()));
  sl.registerLazySingleton<ConfigRepository>(() => ConfigRepository(sl()));
  sl.registerLazySingleton<GoogleSignInService>(() => GoogleSignInService());
  sl.registerLazySingleton<AuthProvider>(() => AuthProvider(sl())..bootstrap());
  sl.registerFactory<GameOnlineProvider>(
    () => GameOnlineProvider(sl(), sl()),
  );
  sl.registerFactory<RoomProvider>(() => RoomProvider(sl()));
  sl.registerFactory<ShopProvider>(() => ShopProvider(sl(), sl()));
  sl.registerFactory<ProfileProvider>(() => ProfileProvider(sl(), sl()));
}
