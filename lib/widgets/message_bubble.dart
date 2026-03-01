import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    final scheme = Theme.of(context).colorScheme;

    final bg = isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final border = isMine
        ? scheme.primary.withValues(alpha: 89)
        : scheme.outline.withValues(alpha: 89);

    final textColor = scheme.onSurface;

    final meta = <String>[];
    if (!isMine) {
      meta.add('hops ${message.hopsRemaining}');
      if (message.receivedFromPeerId != null &&
          message.receivedFromPeerId!.isNotEmpty) {
        meta.add('via ${message.receivedFromPeerId}');
      }
    } else {
      meta.add('direct');
    }

    final decoration = BoxDecoration(
      color: isMine ? null : bg,
      gradient: isMine
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                scheme.secondaryContainer.withValues(alpha: 210),
              ],
            )
          : null,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 7),
            padding: const EdgeInsets.all(12),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderNickname,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isMine ? scheme.onPrimaryContainer : textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.25,
                    color: isMine ? scheme.onPrimaryContainer : textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta.join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
