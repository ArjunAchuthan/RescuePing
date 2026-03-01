import 'dart:math';

import 'package:flutter/material.dart';

import '../models/peer_device.dart';
import '../models/sos_status.dart';

/// Data for one blip on the radar.
class RadarBlip {
  const RadarBlip({
    required this.id,
    required this.label,
    required this.angle,
    required this.distance,
    required this.color,
    this.beacon,
    this.isConnected = false,
  });

  final String id;
  final String label;

  /// Angle in radians (0 = north / top).
  final double angle;

  /// Distance from center: 0.0 = center, 1.0 = edge.
  final double distance;

  final Color color;
  final SosBeacon? beacon;
  final bool isConnected;
}

/// Painter for the rescue radar: range rings, sweep line, and blips.
///
/// Lightweight [CustomPainter] — no heavy GPU work.
class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.sweepAngle,
    required this.blips,
    required this.ringColor,
    required this.sweepColor,
  });

  /// Current angle of the sweep line (radians).
  final double sweepAngle;

  final List<RadarBlip> blips;
  final Color ringColor;
  final Color sweepColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;

    // ─── Background circle ──────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF0D1117),
    );

    // ─── Range rings ────────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3), ringPaint);
    }

    // Cross-hair lines
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ringPaint,
    );

    // ─── Sweep line ─────────────────────────────────────────────────
    final sweepEnd = Offset(
      center.dx + radius * sin(sweepAngle),
      center.dy - radius * cos(sweepAngle),
    );
    final sweepPaint = Paint()
      ..color = sweepColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Sweep trail (fading arc behind the line)
    final trailPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - pi / 3,
        endAngle: sweepAngle,
        colors: [
          sweepColor.withValues(alpha: 0),
          sweepColor.withValues(alpha: 40),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, trailPaint);

    // ─── Center dot (you) ──────────────────────────────────────────
    canvas.drawCircle(
      center,
      5,
      Paint()..color = const Color(0xFF4CAF50),
    );

    // ─── Blips ─────────────────────────────────────────────────────
    for (final blip in blips) {
      final blipRadius = radius * blip.distance.clamp(0.05, 0.92);
      final bx = center.dx + blipRadius * sin(blip.angle);
      final by = center.dy - blipRadius * cos(blip.angle);

      // Glow
      canvas.drawCircle(
        Offset(bx, by),
        10,
        Paint()..color = blip.color.withValues(alpha: 50),
      );

      // Dot
      canvas.drawCircle(
        Offset(bx, by),
        5,
        Paint()..color = blip.color,
      );
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.blips.length != blips.length;
  }
}

/// Builds [RadarBlip] list from peers and SOS beacons.
///
/// Uses deterministic angles derived from device IDs so positions are stable.
List<RadarBlip> buildRadarBlips({
  required List<PeerDevice> peers,
  required List<SosBeacon> beacons,
  required String localDeviceId,
}) {
  final blips = <RadarBlip>[];
  final beaconDeviceIds = <String>{};

  // SOS beacons first (they are more important).
  for (final b in beacons) {
    if (b.senderDeviceId == localDeviceId) continue;

    beaconDeviceIds.add(b.senderDeviceId);

    final angle = _stableAngle(b.senderDeviceId);
    final distance = b.hasLocation ? 0.5 : 0.65;

    blips.add(RadarBlip(
      id: b.senderDeviceId,
      label: b.senderNickname,
      angle: angle,
      distance: distance,
      color: _sosColor(b.level),
      beacon: b,
    ));
  }

  // Connected / discovered peers (not already shown as SOS beacons).
  for (final p in peers) {
    if (beaconDeviceIds.contains(p.peerId)) continue;

    final angle = _stableAngle(p.peerId);
    final distance = p.isConnected ? 0.35 : 0.75;

    blips.add(RadarBlip(
      id: p.peerId,
      label: p.displayName,
      angle: angle,
      distance: distance,
      color: p.isConnected
          ? const Color(0xFF4CAF50)
          : const Color(0xFF78909C),
      isConnected: p.isConnected,
    ));
  }

  return blips;
}

/// Deterministic angle from a device ID so blips don't jump around.
double _stableAngle(String id) {
  var hash = 0;
  for (var i = 0; i < id.length; i++) {
    hash = (hash * 31 + id.codeUnitAt(i)) & 0x7FFFFFFF;
  }
  return (hash % 360) * pi / 180;
}

Color _sosColor(SosLevel level) {
  switch (level) {
    case SosLevel.trapped:
      return const Color(0xFFB71C1C);
    case SosLevel.injured:
      return const Color(0xFFE65100);
    case SosLevel.needHelp:
      return const Color(0xFFF57F17);
    case SosLevel.safe:
      return const Color(0xFF4CAF50);
  }
}
