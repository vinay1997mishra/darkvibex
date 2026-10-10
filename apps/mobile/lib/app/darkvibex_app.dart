import 'package:flutter/material.dart';

import '../core/app_identity.dart';

class DarkVibeXApp extends StatelessWidget {
  const DarkVibeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'DarkVibeX',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
