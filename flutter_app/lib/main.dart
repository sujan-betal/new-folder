import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injection_container.dart' as di;
import 'core/sound/haptics.dart';
import 'core/sound/sound_manager.dart';
import 'core/theme/app_theme.dart';
import 'logic/providers/auth_provider.dart';
import 'presentation/screens/splash_screen.dart';

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

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

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
