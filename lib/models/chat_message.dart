class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderDeviceId,
    required this.senderNickname,
    required this.body,
    required this.createdAtMs,
    required this.hopsRemaining,
    required this.receivedFromPeerId,
    required this.isMine,
  });

  /// Globally unique ID to dedupe + prevent infinite forwarding.
  final String messageId;

  /// Stable ID of the original sender device (stored in SharedPreferences).
  final String senderDeviceId;

  final String senderNickname;
  final String body;
  final int createdAtMs;

  /// Pseudo-mesh TTL. Decremented each time a device forwards.
  final int hopsRemaining;

  /// Which peer we directly received it from (null/empty for local messages).
  final String? receivedFromPeerId;

  /// True when created on this device.
  final bool isMine;

  ChatMessage copyWith({
    String? messageId,
    String? senderDeviceId,
    String? senderNickname,
    String? body,
    int? createdAtMs,
    int? hopsRemaining,
    String? receivedFromPeerId,
    bool? isMine,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      senderNickname: senderNickname ?? this.senderNickname,
      body: body ?? this.body,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      hopsRemaining: hopsRemaining ?? this.hopsRemaining,
      receivedFromPeerId: receivedFromPeerId ?? this.receivedFromPeerId,
      isMine: isMine ?? this.isMine,
    );
  }
}
