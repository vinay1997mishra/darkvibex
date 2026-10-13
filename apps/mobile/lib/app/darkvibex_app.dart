import 'package:flutter/material.dart';

import '../core/app_identity.dart';
import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../ui/tinni_style.dart';
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
    return MaterialApp(
      title: AppIdentity.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTinniStyleTheme(),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (state.isInitializing) {
            return const Scaffold(
              body: TinniBackground(
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (!state.isAuthenticated) {
            return LoginScreen(state: state);
          }
          return HomeShell(state: state);
        },
      ),
    );
  }}
