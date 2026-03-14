import 'package:flutter/material.dart';

import '../models/sos_status.dart';

/// Card widget showing an incoming SOS beacon from another device.
class SosBeaconCard extends StatelessWidget {
  const SosBeaconCard({super.key, required this.beacon, this.onTap});

  final SosBeacon beacon;
  final VoidCallback? onTap;

  Color _borderColor() {
    switch (beacon.level) {
      case SosLevel.trapped:
        return const Color(0xFFB71C1C);
      case SosLevel.injured:
        return const Color(0xFFE65100);
      case SosLevel.needHelp:
        return const Color(0xFFF57F17);
      case SosLevel.safe:
        return Colors.green;
    }
  }

  IconData _icon() {
    switch (beacon.level) {
      case SosLevel.trapped:
        return Icons.warning_amber_rounded;
      case SosLevel.injured:
        return Icons.local_hospital;
      case SosLevel.needHelp:
        return Icons.pan_tool;
      case SosLevel.safe:
        return Icons.check_circle;
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().millisecondsSinceEpoch - beacon.timestampMs;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    return '${diff ~/ 3600000}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _borderColor();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 50),
                child: Icon(_icon(), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            beacon.senderNickname,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _timeAgo(),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            beacon.level.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (beacon.peopleCount > 1) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.people,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${beacon.peopleCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (beacon.bloodGroup.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.bloodtype,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            beacon.bloodGroup,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (beacon.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        beacon.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (beacon.hasLocation) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${beacon.latitude!.toStringAsFixed(4)}, ${beacon.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
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
