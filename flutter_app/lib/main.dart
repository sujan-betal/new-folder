import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'logic/providers/auth_provider.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const SplashScreen(),
      ),
    );
  }
}
