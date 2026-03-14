import 'package:flutter/material.dart';

import '../models/sos_status.dart';

/// Large animated "ALERT OTHERS" / "SOS ACTIVE" button.
///
/// Pulses red when an SOS is active.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.isActive,
    required this.currentLevel,
    required this.onTap,
    required this.onLongPress,
  });

  final bool isActive;
  final SosLevel currentLevel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _buttonColor(ColorScheme scheme) {
    if (!widget.isActive) return const Color(0xFFD32F2F); // Deep red
    switch (widget.currentLevel) {
      case SosLevel.trapped:
        return const Color(0xFFB71C1C);
      case SosLevel.injured:
        return const Color(0xFFE65100);
      case SosLevel.needHelp:
        return const Color(0xFFF57F17);
      case SosLevel.safe:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _buttonColor(scheme);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isActive ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.8),
                  color,
                ],
                center: const Alignment(-0.2, -0.2),
                radius: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: widget.isActive ? 0.6 : 0.4),
                  blurRadius: widget.isActive ? 50 : 25,
                  spreadRadius: widget.isActive ? 12 : 4,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isActive ? Icons.wifi_tethering : Icons.sos,
                  size: 56,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isActive ? 'SOS ACTIVE' : 'ALERT\nOTHERS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet level picker for SOS severity.
class SosLevelPicker extends StatelessWidget {
  const SosLevelPicker({super.key, required this.onSelected});

  final ValueChanged<SosLevel> onSelected;

  static const _levels = [
    SosLevel.needHelp,
    SosLevel.injured,
    SosLevel.trapped,
  ];

  Color _color(SosLevel level) {
    switch (level) {
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

  IconData _icon(SosLevel level) {
    switch (level) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Emergency Level',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your location will be sent to nearby rescuers.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._levels.map((level) {
            final color = _color(level);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSelected(level);
                  },
                  icon: Icon(_icon(level), color: Colors.white),
                  label: Text(
                    level.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
