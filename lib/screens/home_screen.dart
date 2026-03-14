import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sos_status.dart';
import '../services/app_state.dart';
import '../widgets/sos_beacon_card.dart';
import '../widgets/sos_button.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'profile_setup_screen.dart';
import 'role_selection_screen.dart';

/// Main home screen for trapped persons — 3 tabs: Home, Chat, Mesh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _Tab(icon: Icons.home, label: 'Home'),
    _Tab(icon: Icons.chat_bubble_outline, label: 'Chat'),
    _Tab(icon: Icons.wifi_tethering, label: 'Mesh'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _DashboardTab(),
          ChatScreen(),
          DiscoveryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The main dashboard tab for trapped persons.
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  StreamSubscription<String>? _rescueConfirmSub;

  @override
  void initState() {
    super.initState();
    // Listen for incoming rescue confirmations.
    Future.microtask(() {
      if (!mounted) return;
      final state = context.read<AppState>();
      _rescueConfirmSub = state.rescueConfirmReceived.listen((rescuerName) {
        if (!mounted) return;
        _showRescueConfirmDialog(rescuerName);
      });
    });
  }

  @override
  void dispose() {
    _rescueConfirmSub?.cancel();
    super.dispose();
  }

  void _showRescueConfirmDialog(String rescuerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.health_and_safety,
          size: 48,
          color: Color(0xFF4CAF50),
        ),
        title: const Text('Rescue Confirmation'),
        content: Text(
          '$rescuerName has marked you as rescued.\n\n'
          'Do you confirm that you have been safely rescued?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().confirmRescued();
            },
            icon: const Icon(Icons.check),
            label: const Text('Yes, I\'m Safe'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  void _alertOthers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SosLevelPicker(
        onSelected: (level) {
          context.read<AppState>().alertOthers(level: level);
        },
      ),
    );
  }

  void _quickAlert(BuildContext context) {
    final state = context.read<AppState>();
    if (state.isSosActive) {
      state.cancelAlert();
    } else {
      state.alertOthers(level: SosLevel.needHelp);
    }
  }

  void _selfConfirmRescue() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          size: 48,
          color: Color(0xFF4CAF50),
        ),
        title: const Text('Confirm Rescue'),
        content: const Text(
          'Are you sure you have been safely rescued?\n\n'
          'This will cancel your SOS alert and reset your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().confirmRescued();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Yes, I\'m Rescued'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final alertCount = state.activeAlerts.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('RescuePing'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ProfileSetupScreen(isEditing: true),
                    ),
                  );
                case 'switch':
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: Icon(
                        Icons.swap_horiz_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Switch Role'),
                      content: const Text(
                        'This will reset your profile and take you back '
                        'to the role selection screen.\n\nAre you sure?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await context.read<AppState>().resetApp();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const RoleSelectionScreen(),
                              ),
                              (_) => false,
                            );
                          },
                          child: const Text('Switch'),
                        ),
                      ],
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Edit Profile'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'switch',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('Switch Role'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ─── SOS Button ───────────────────────────────────
                SosButton(
                  isActive: state.isSosActive,
                  currentLevel: state.currentSosLevel,
                  onTap: () => _quickAlert(context),
                  onLongPress: () => _alertOthers(context),
                ),

                const SizedBox(height: 16),

                // ─── Status text ──────────────────────────────────
                if (state.isSosActive) ...[
                  Text(
                    'SOS Active — ${state.currentSosLevel.label}',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => state.cancelAlert(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Alert'),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                  ),
                  const SizedBox(height: 8),
                  // ─── "I've Been Rescued" button ──────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF81C784), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _selfConfirmRescue,
                      icon: const Icon(Icons.health_and_safety, color: Colors.white),
                      label: const Text(
                        'I\'ve Been Rescued',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Tap to send quick alert',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Long press for severity picker',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 150),
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ─── Stats bar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.people,
                            value: '${state.peers.length}',
                            label: 'Devices',
                          ),
                          _StatItem(
                            icon: Icons.link,
                            value:
                                '${state.peers.where((p) => p.isConnected).length}',
                            label: 'Connected',
                          ),
                          _StatItem(
                            icon: Icons.warning_amber,
                            value: '$alertCount',
                            label: 'Alerts',
                            color: alertCount > 0 ? scheme.error : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Section header ───────────────────────────────
                if (state.activeAlerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.error.withValues(alpha: 0.8),
                                const Color(0xFFD32F2F),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.error.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.sos_rounded, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Nearby Alerts',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ─── Alert cards ─────────────────────────────────────────
          if (state.activeAlerts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: state.activeAlerts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return SosBeaconCard(beacon: state.activeAlerts[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: c,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
