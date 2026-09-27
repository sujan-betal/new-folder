import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/deep_link_service.dart';
import 'core/sound/haptics.dart';
import 'core/sound/sound_manager.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart' as di;
import 'logic/providers/auth_provider.dart';
import 'presentation/screens/online/rooms_screen.dart';
import 'presentation/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warm the audio + haptics layer before the first frame so the very first
  // dice roll already has its rattle cached and the music loop is seamless.
  try {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      SoundManager.instance.init(prefs),
      Haptics.instance.init(prefs),
    ]);
    unawaited(SoundManager.instance.startMusic());
  } catch (_) {}

  await di.init();
  runApp(const LudoApp());
}

class LudoApp extends StatefulWidget {
  const LudoApp({super.key});

  @override
  State<LudoApp> createState() => _LudoAppState();
}

class _LudoAppState extends State<LudoApp> {
  final DeepLinkService _deepLink = DeepLinkService();
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _deepLink.start().then((_) {
      _deepLinkSub = _deepLink.codes.listen(_handleDeepLink);
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _deepLink.dispose();
    super.dispose();
  }

  /// A tapped invite (`ludo://join/<CODE>`) signs the user in as a guest when
  /// needed and drops them straight into that room's lobby - the Ludo King
  /// one-tap experience.
  Future<void> _handleDeepLink(String code) async {
    final auth = context.read<AuthProvider>();
    if (!auth.bootstrapped) await auth.bootstrap();
    if (!mounted) return;
    if (!auth.isAuthenticated) {
      final ok = await auth.loginAsGuest();
      if (!ok || !mounted) return;
    }
    _pushJoin(code);
  }

  void _pushJoin(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || navigatorKey.currentState == null) return;
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(roomCode: code.toUpperCase()),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
      ],
      child: MaterialApp(
        title: 'Ludo Master',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        navigatorKey: navigatorKey,
        home: const _AudioLifecycle(child: SplashScreen()),
      ),
    );
  }
}

/// Silences the game while the app is not on screen and restores it after.
class _AudioLifecycle extends StatefulWidget {
  const _AudioLifecycle({required this.child});

  final Widget child;

  @override
  State<_AudioLifecycle> createState() => _AudioLifecycleState();
}

class _AudioLifecycleState extends State<_AudioLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        SoundManager.instance.pauseAll();
      case AppLifecycleState.resumed:
        SoundManager.instance.resumeAll();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
