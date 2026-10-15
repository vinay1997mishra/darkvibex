import 'dart:async';

import 'package:flutter/material.dart';

import '../background/message_push_service.dart';
import '../core/app_identity.dart';
import '../infra/invite_referral_service.dart';
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
  late final InviteReferralService inviteReferral;

  @override
  void initState() {
    super.initState();
    state.addListener(_syncMessagePush);
    inviteReferral = InviteReferralService(state);
    unawaited(inviteReferral.initialize());
    unawaited(state.initialize().whenComplete(_syncMessagePush));
  }

  void _syncMessagePush() {
    unawaited(messagePush.sync(state));
  }

  @override
  void dispose() {
    state.removeListener(_syncMessagePush);
    inviteReferral.dispose();
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTinniStyleTheme(),
      builder: (context, child) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final room = state.minimizedRoom;
          return Stack(
            children: [
              Positioned.fill(
                child: child ?? const SizedBox.shrink(),
              ),
              if (room != null)
                Positioned.fill(
                  child: SafeArea(
                    child: MinimizedRoomBubble(
                      state: state,
                      room: room,
                      onResume: state.minimizedRoomResume,
                      onClose: state.minimizedRoomClose,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
