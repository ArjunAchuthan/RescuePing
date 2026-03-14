import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sos_status.dart';
import '../services/app_state.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'profile_setup_screen.dart';
import 'rescuer_map_screen.dart';
import 'role_selection_screen.dart';

/// Home screen for rescuers — Dashboard with SOS list, Chat, and Mesh tabs.
class RescuerHomeScreen extends StatefulWidget {
  const RescuerHomeScreen({super.key});

  @override
  State<RescuerHomeScreen> createState() => _RescuerHomeScreenState();
}

class _RescuerHomeScreenState extends State<RescuerHomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _Tab(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _Tab(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
    _Tab(icon: Icons.wifi_tethering_rounded, label: 'Mesh'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _RescuerDashboard(),
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

/// Rescuer dashboard — shows active SOS alerts with actions.
class _RescuerDashboard extends StatelessWidget {
  const _RescuerDashboard();

  void _switchRole(BuildContext context) {
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
          'This will reset your profile and take you back to the role selection screen.\n\n'
          'Are you sure?',
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final alerts = state.activeAlerts;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 40),
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
                  _switchRole(context);
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Hero stats card ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1565C0).withValues(alpha: 30),
                          const Color(0xFF111E36),
                          scheme.surfaceContainerHighest,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _GlowingStat(
                              icon: Icons.people_rounded,
                              value: '${state.peers.length}',
                              label: 'Devices',
                              color: const Color(0xFF64B5F6),
                            ),
                            _GlowingStat(
                              icon: Icons.link_rounded,
                              value:
                                  '${state.peers.where((p) => p.isConnected).length}',
                              label: 'Connected',
                              color: const Color(0xFF81C784),
                            ),
                            _GlowingStat(
                              icon: Icons.warning_amber_rounded,
                              value: '${alerts.length}',
                              label: 'Distress',
                              color: alerts.isNotEmpty
                                  ? const Color(0xFFEF5350)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Section header ─────────────────────────
                  Row(
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
                        child: const Icon(Icons.sos_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'People in Distress',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                      ),
                      const Spacer(),
                      if (alerts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: scheme.error.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${alerts.length} ACTIVE',
                            style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view details and navigate',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 170),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ─── Alert cards ────────────────────────────────────
          if (alerts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF81C784), Color(0xFF388E3C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All clear',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No active distress signals',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${state.peers.length} devices on mesh • scanning…',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 130),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: alerts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _AlertCard(beacon: alerts[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GlowingStat extends StatelessWidget {
  const _GlowingStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 180),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.beacon});
  final SosBeacon beacon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color levelColor;
    IconData levelIcon;
    switch (beacon.level) {
      case SosLevel.trapped:
        levelColor = const Color(0xFFEF5350);
        levelIcon = Icons.warning_rounded;
      case SosLevel.injured:
        levelColor = const Color(0xFFFF9800);
        levelIcon = Icons.local_hospital_rounded;
      case SosLevel.needHelp:
        levelColor = const Color(0xFFFDD835);
        levelIcon = Icons.help_outline_rounded;
      case SosLevel.safe:
        levelColor = const Color(0xFF66BB6A);
        levelIcon = Icons.check_circle_rounded;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RescuerMapScreen(beacon: beacon),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: levelColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(levelIcon, color: levelColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beacon.senderNickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            beacon.level.label.toUpperCase(),
                            style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 80),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 80),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (beacon.hasLocation) ...[
                      Icon(Icons.location_on_rounded,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${beacon.latitude!.toStringAsFixed(4)}, ${beacon.longitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.location_off_rounded,
                          size: 14, color: scheme.error),
                      const SizedBox(width: 4),
                      Text(
                        'No GPS',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (beacon.bloodGroup.isNotEmpty) ...[
                      Icon(Icons.bloodtype_rounded,
                          size: 14, color: scheme.error),
                      const SizedBox(width: 4),
                      Text(
                        beacon.bloodGroup,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                        Icons.people_rounded, size: 14, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${beacon.peopleCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
