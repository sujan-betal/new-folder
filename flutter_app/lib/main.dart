import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart' as di;
import 'logic/providers/auth_provider.dart';
import 'presentation/screens/online/rooms_screen.dart';
import 'presentation/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const SplashScreen(),
      ),
    );
  }
}