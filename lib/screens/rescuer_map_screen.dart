import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_status.dart';
import '../services/app_state.dart';
import '../services/location_service.dart';

/// Full-screen details + directions for a specific SOS alert.
class RescuerMapScreen extends StatefulWidget {
  const RescuerMapScreen({super.key, required this.beacon});

  final SosBeacon beacon;

  @override
  State<RescuerMapScreen> createState() => _RescuerMapScreenState();
}

class _RescuerMapScreenState extends State<RescuerMapScreen> {
  final LocationService _location = LocationService();
  bool _launching = false;

  Future<void> _openMaps() async {
    if (!widget.beacon.hasLocation) return;

    setState(() => _launching = true);

    // Get rescuer's current position for the starting point.
    final pos = await _location.getLocationOnce();

    final destLat = widget.beacon.latitude!;
    final destLng = widget.beacon.longitude!;

    Uri mapsUri;
    if (pos != null) {
      // Google Maps directions from rescuer → trapped person.
      mapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${pos.latitude},${pos.longitude}'
        '&destination=$destLat,$destLng'
        '&travelmode=driving',
      );
    } else {
      // Fallback: just show the destination.
      mapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng',
      );
    }

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps application')),
      );
    }

    if (mounted) setState(() => _launching = false);
  }

  void _markRescued() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 40, color: Color(0xFF4CAF50)),
        title: const Text('Confirm Rescue'),
        content: Text(
          'Mark ${widget.beacon.senderNickname} as rescued?\n\n'
          'This will send a confirmation to their device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().markAsRescued(widget.beacon.senderDeviceId);
              Navigator.pop(context); // Return to dashboard.
            },
            child: const Text('Yes, Rescued'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final beacon = widget.beacon;

    Color levelColor;
    switch (beacon.level) {
      case SosLevel.trapped:
        levelColor = const Color(0xFFB71C1C);
      case SosLevel.injured:
        levelColor = const Color(0xFFE65100);
      case SosLevel.needHelp:
        levelColor = const Color(0xFFF57F17);
      case SosLevel.safe:
        levelColor = const Color(0xFF4CAF50);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(beacon.senderNickname),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF111E36),
                    scheme.surface,
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Severity header ─────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  levelColor.withValues(alpha: 0.15),
                  scheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: levelColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 60),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.warning_amber,
                      size: 30,
                      color: levelColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beacon.level.label,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: levelColor,
                          ),
                        ),
                        Text(
                          '${beacon.peopleCount} ${beacon.peopleCount == 1 ? 'person' : 'people'} at this location',
                          style: TextStyle(
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

          const SizedBox(height: 16),

          // ─── Details card ───────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.person,
                    label: 'Name',
                    value: beacon.senderNickname,
                  ),
                  if (beacon.bloodGroup.isNotEmpty)
                    _InfoRow(
                      icon: Icons.bloodtype,
                      label: 'Blood Group',
                      value: beacon.bloodGroup,
                    ),
                  if (beacon.hasLocation) ...[
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Latitude',
                      value: beacon.latitude!.toStringAsFixed(6),
                    ),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Longitude',
                      value: beacon.longitude!.toStringAsFixed(6),
                    ),
                  ],
                  if (beacon.message.isNotEmpty)
                    _InfoRow(
                      icon: Icons.message,
                      label: 'Message',
                      value: beacon.message,
                    ),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Sent',
                    value: _formatTime(beacon.timestampMs),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ─── Action buttons ─────────────────────────
          if (beacon.hasLocation)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _launching ? null : _openMaps,
                icon: _launching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.directions_rounded, color: Colors.white),
                label: const Text(
                  'Get Directions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

          if (!beacon.hasLocation)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_off, color: scheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No GPS coordinates available for this person.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
              ),
            ),
            child: OutlinedButton.icon(
              onPressed: _markRescued,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Rescued'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: const Color(0xFF4CAF50),
                side: BorderSide.none,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
