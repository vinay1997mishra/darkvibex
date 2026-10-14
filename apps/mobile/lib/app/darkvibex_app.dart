import 'dart:async';

import 'package:flutter/material.dart';

import '../background/message_push_service.dart';
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
  final MessagePushService messagePush = MessagePushService();

  @override
  void initState() {
    super.initState();
    state.addListener(_syncMessagePush);
    unawaited(state.initialize().whenComplete(_syncMessagePush));
  }

  void _syncMessagePush() {
    unawaited(messagePush.sync(state));
  }

  @override
  void dispose() {
    state.removeListener(_syncMessagePush);
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
