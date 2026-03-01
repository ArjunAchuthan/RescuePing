import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppState>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // No profile / nickname yet → show profile setup.
    if (state.nickname == null || state.nickname!.isEmpty) {
      return const ProfileSetupScreen();
    }

    // Returning user → go to the rescue dashboard.
    return const HomeScreen();
  }
}
