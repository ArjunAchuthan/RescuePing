import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sos_status.dart';
import '../services/app_state.dart';
import '../widgets/sos_beacon_card.dart';
import '../widgets/sos_button.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'profile_setup_screen.dart';
import 'radar_screen.dart';

/// Main rescue dashboard with bottom navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _Tab(icon: Icons.home, label: 'Home'),
    _Tab(icon: Icons.radar, label: 'Radar'),
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
          RadarScreen(),
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

/// The main dashboard tab with the ALERT OTHERS button.
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final alertCount = state.activeAlerts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescue Mesh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileSetupScreen(isEditing: true),
              ),
            ),
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
                        Icon(Icons.sos, size: 18, color: scheme.error),
                        const SizedBox(width: 6),
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
