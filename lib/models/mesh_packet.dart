import 'dart:convert';

/// Minimal wire format.
///
/// We keep this explicit (instead of sending a raw ChatMessage) so that we can
/// evolve the protocol safely and include mesh-specific fields like hops.
///
/// Supported types:
///   - `chat`  – regular text message (body field)
///   - `sos`   – SOS beacon with GPS & profile (payload field)
class MeshPacket {
  const MeshPacket({
    required this.type,
    required this.messageId,
    required this.senderDeviceId,
    required this.senderNickname,
    this.body = '',
    required this.createdAtMs,
    required this.hopsRemaining,
    this.payload,
  });

  /// Packet type: 'chat', 'sos', etc.
  final String type;

  final String messageId;
  final String senderDeviceId;
  final String senderNickname;

  /// Text body (used by chat messages).
  final String body;

  final int createdAtMs;
  final int hopsRemaining;

  /// Optional typed payload (used by SOS packets, future extensions).
  final Map<String, Object?>? payload;

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'messageId': messageId,
      'senderDeviceId': senderDeviceId,
      'senderNickname': senderNickname,
      'body': body,
      'createdAtMs': createdAtMs,
      'hopsRemaining': hopsRemaining,
      if (payload != null) 'payload': payload,
    };
  }

  static MeshPacket fromJson(Map<String, Object?> json) {
    return MeshPacket(
      type: (json['type'] as String?) ?? 'chat',
      messageId: json['messageId'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      senderNickname: json['senderNickname'] as String,
      body: (json['body'] as String?) ?? '',
      createdAtMs: (json['createdAtMs'] as num).toInt(),
      hopsRemaining: (json['hopsRemaining'] as num).toInt(),
      payload: json['payload'] != null
          ? (json['payload'] as Map).cast<String, Object?>()
          : null,
    );
  }

  /// Encode as compact JSON.
  String encode() => jsonEncode(toJson());

  static MeshPacket decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid packet JSON');
    }
    return MeshPacket.fromJson(decoded.cast<String, Object?>());
  }
}
