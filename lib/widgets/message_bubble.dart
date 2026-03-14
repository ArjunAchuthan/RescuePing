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

    // WhatsApp-style asymmetric bubbles
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
      bottomRight: isMine ? Radius.zero : const Radius.circular(16),
    );

    // Bluish-black sleek colors
    final bg = isMine
        ? const Color(0xFF1E3A5F) // Deep solid blue for my messages
        : const Color(0xFF162032); // Dark bluish-grey for others

    // Formatted time
    final time = DateTime.fromMillisecondsSinceEpoch(message.createdAtMs);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender Name (Only for received messages)
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderNickname,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: scheme.primary, // Colorful sender name
                      ),
                    ),
                  ),

                // Message Body
                Text(
                  message.body,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 6),

                // Time and Meta Info (WhatsApp style bottom right)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isMine ? timeStr : '${meta.join(' • ')}  $timeStr',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.done_all, // WhatsApp 'read' tick
                        size: 14,
                        color: scheme.primary, // Blueish tick
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
