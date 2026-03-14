import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/app_state.dart';
import 'home_screen.dart';
import 'rescuer_home_screen.dart';
import 'role_selection_screen.dart';

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

    // No profile / nickname yet → show role selection.
    if (state.nickname == null || state.nickname!.isEmpty) {
      return const RoleSelectionScreen();
    }

    // Route by role.
    if (state.userRole == UserRole.rescuer) {
      return const RescuerHomeScreen();
    }

    // Default: trapped person / need help.
    return const HomeScreen();
  }
}
