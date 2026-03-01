import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sos_status.dart';
import '../services/app_state.dart';
import '../widgets/radar_painter.dart';
import '../widgets/sos_beacon_card.dart';

/// Full-screen rescue radar.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  void _showBeaconDetails(SosBeacon beacon) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              beacon.senderNickname,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.warning,
              label: 'Status',
              value: beacon.level.label,
            ),
            if (beacon.bloodGroup.isNotEmpty)
              _DetailRow(
                icon: Icons.bloodtype,
                label: 'Blood Group',
                value: beacon.bloodGroup,
              ),
            _DetailRow(
              icon: Icons.people,
              label: 'People',
              value: '${beacon.peopleCount}',
            ),
            if (beacon.hasLocation)
              _DetailRow(
                icon: Icons.location_on,
                label: 'Location',
                value:
                    '${beacon.latitude!.toStringAsFixed(5)}, ${beacon.longitude!.toStringAsFixed(5)}',
              ),
            if (beacon.message.isNotEmpty)
              _DetailRow(
                icon: Icons.message,
                label: 'Message',
                value: beacon.message,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final blips = buildRadarBlips(
      peers: state.peers,
      beacons: state.nearbyBeacons,
      localDeviceId: state.deviceId ?? '',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Rescue Radar'),
        backgroundColor: const Color(0xFF0D1117),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-scan',
            onPressed: () => state.restartDiscovery(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Radar ─────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final radarSize = min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Center(
                    child: GestureDetector(
                      onTapUp: (details) =>
                          _handleRadarTap(details, radarSize, blips),
                      child: AnimatedBuilder(
                        animation: _sweepController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(radarSize, radarSize),
                            painter: RadarPainter(
                              sweepAngle: _sweepController.value * 2 * pi,
                              blips: blips,
                              ringColor: scheme.primary.withValues(alpha: 60),
                              sweepColor: const Color(0xFF4CAF50),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── Legend + stats ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: const Color(0xFF4CAF50), label: 'You/Safe'),
                const SizedBox(width: 12),
                _LegendDot(color: const Color(0xFFF57F17), label: 'Need Help'),
                const SizedBox(width: 12),
                _LegendDot(color: const Color(0xFFE65100), label: 'Injured'),
                const SizedBox(width: 12),
                _LegendDot(color: const Color(0xFFB71C1C), label: 'Trapped'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ─── Active alerts list ────────────────────────────
          if (state.activeAlerts.isNotEmpty)
            Expanded(
              flex: 2,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: state.activeAlerts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final beacon = state.activeAlerts[index];
                  return SosBeaconCard(
                    beacon: beacon,
                    onTap: () => _showBeaconDetails(beacon),
                  );
                },
              ),
            )
          else
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar,
                      size: 36,
                      color: scheme.onSurfaceVariant.withValues(alpha: 100),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active alerts nearby',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${state.peers.length} devices on mesh',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleRadarTap(
    TapUpDetails details,
    double radarSize,
    List<RadarBlip> blips,
  ) {
    final center = Offset(radarSize / 2, radarSize / 2);
    final radius = radarSize / 2 - 8;
    final tapPos = details.localPosition;

    for (final blip in blips) {
      final blipRadius = radius * blip.distance.clamp(0.05, 0.92);
      final bx = center.dx + blipRadius * sin(blip.angle);
      final by = center.dy - blipRadius * cos(blip.angle);

      final dist = (tapPos - Offset(bx, by)).distance;
      if (dist < 24 && blip.beacon != null) {
        _showBeaconDetails(blip.beacon!);
        return;
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
