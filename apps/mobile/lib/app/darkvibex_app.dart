import 'package:flutter/material.dart';

import '../core/app_identity.dart';
import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import 'app_state.dart';

class DarkVibeXApp extends StatefulWidget {
  const DarkVibeXApp({super.key});

  @override
  State<DarkVibeXApp> createState() => _DarkVibeXAppState();
}

class _DarkVibeXAppState extends State<DarkVibeXApp> {
  final AppState state = AppState();

  @override
  void initState() {
    super.initState();
    state.initialize();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD36A);
    const background = Color(0xFF09090B);

    return MaterialApp(
      title: AppIdentity.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: const Color(0xFF111217),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF14151A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF101116),
          indicatorColor: Color(0x33FFD36A),
        ),
      ),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (state.isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!state.isAuthenticated) {
            return LoginScreen(state: state);
          }
          return HomeShell(state: state);
        },
      ),
    );
  }
}
