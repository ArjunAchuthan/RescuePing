import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../models/chat_message.dart';
import '../../models/mesh_packet.dart';
import '../../models/sos_status.dart';
import '../transport/mesh_transport.dart';

/// Implements pseudo-mesh forwarding.
///
/// Core ideas:
/// - Every message has a globally unique `messageId`.
/// - We persist `messageId` in SQLite (table `seen_messages`) the first time we
///   see it. If we see it again, we drop it (prevents infinite loops + duplicates).
/// - We attach a `hopsRemaining` (TTL). Each hop decrements it.
/// - When a message arrives from peer X, we forward it to all other connected
///   peers except X (and only if hopsRemaining > 0).
///
/// Supported packet types:
///   - 'chat'            – regular text message
///   - 'sos'             – SOS beacon with GPS & profile info
///   - 'rescue_confirm'  – rescuer marks a trapped person as rescued
class MessageRelayManager {
  MessageRelayManager({
    required this.database,
    required this.transport,
    required this.localDeviceId,
    required this.localNickname,
    this.defaultHopLimit = 6,
  });

  final AppDatabase database;
  final MeshTransport transport;
  final String localDeviceId;
  String localNickname;

  /// Default TTL for locally-created messages.
  final int defaultHopLimit;

  final _uuid = const Uuid();
  StreamSubscription<IncomingBytes>? _incomingSub;

  final _messageAddedController = StreamController<void>.broadcast();
  Stream<void> get messageAdded => _messageAddedController.stream;

  final _sosReceivedController = StreamController<SosBeacon>.broadcast();
  Stream<SosBeacon> get sosReceived => _sosReceivedController.stream;

  /// Emits the rescuer's nickname when a rescue_confirm is received for this device.
  final _rescueConfirmController = StreamController<String>.broadcast();
  Stream<String> get rescueConfirmReceived => _rescueConfirmController.stream;

  Future<void> start() async {
    _incomingSub = transport.incoming.listen(_handleIncomingBytes);
  }

  Future<void> stop() async {
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _messageAddedController.close();
    await _sosReceivedController.close();
    await _rescueConfirmController.close();
  }

  // ─── Send local chat message ─────────────────────────────────────

  Future<void> sendLocalMessage(String body) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final messageId = _uuid.v7();

    final packet = MeshPacket(
      type: 'chat',
      messageId: messageId,
      senderDeviceId: localDeviceId,
      senderNickname: localNickname,
      body: body,
      createdAtMs: now,
      hopsRemaining: defaultHopLimit,
    );

    await database.markSeenMessageId(packet.messageId);

    await database.insertMessage(
      ChatMessage(
        messageId: packet.messageId,
        senderDeviceId: packet.senderDeviceId,
        senderNickname: packet.senderNickname,
        body: packet.body,
        createdAtMs: packet.createdAtMs,
        hopsRemaining: packet.hopsRemaining,
        receivedFromPeerId: null,
        isMine: true,
      ),
    );

    _messageAddedController.add(null);

    final bytes = Uint8List.fromList(utf8.encode(packet.encode()));
    await transport.broadcast(bytes);
  }

  // ─── Send local SOS beacon ──────────────────────────────────────

  Future<void> sendSosBeacon(SosBeacon beacon) async {
    final messageId = _uuid.v7();

    final packet = MeshPacket(
      type: 'sos',
      messageId: messageId,
      senderDeviceId: beacon.senderDeviceId,
      senderNickname: beacon.senderNickname,
      createdAtMs: beacon.timestampMs,
      hopsRemaining: defaultHopLimit,
      payload: beacon.toPayload(),
    );

    await database.markSeenMessageId(packet.messageId);
    await database.upsertSosBeacon(beacon);
    _sosReceivedController.add(beacon);

    final bytes = Uint8List.fromList(utf8.encode(packet.encode()));
    await transport.broadcast(bytes);
  }

  // ─── Send rescue confirmation ───────────────────────────────────

  /// Broadcast a rescue_confirm packet targeting [targetDeviceId].
  Future<void> sendRescueConfirm(String targetDeviceId) async {
    final messageId = _uuid.v7();

    final packet = MeshPacket(
      type: 'rescue_confirm',
      messageId: messageId,
      senderDeviceId: localDeviceId,
      senderNickname: localNickname,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      hopsRemaining: defaultHopLimit,
      payload: {'targetDeviceId': targetDeviceId},
    );

    await database.markSeenMessageId(packet.messageId);

    final bytes = Uint8List.fromList(utf8.encode(packet.encode()));
    await transport.broadcast(bytes);
  }

  // ─── Handle incoming ────────────────────────────────────────────

  Future<void> _handleIncomingBytes(IncomingBytes incoming) async {
    MeshPacket packet;
    try {
      final raw = utf8.decode(incoming.bytes);
      packet = MeshPacket.decode(raw);
    } catch (_) {
      return;
    }

    // De-dupe: only the first device that sees a given messageId will process it.
    final firstTime = await database.markSeenMessageId(packet.messageId);
    if (!firstTime) return;

    switch (packet.type) {
      case 'chat':
        await _handleChatPacket(packet, incoming.fromPeerId);
      case 'sos':
        await _handleSosPacket(packet, incoming.fromPeerId);
      case 'rescue_confirm':
        await _handleRescueConfirmPacket(packet);
      default:
        // Unknown type – ignore but still forward.
        break;
    }

    // Forwarding rule:
    // - Never forward if hopsRemaining <= 0
    // - Otherwise, decrement and broadcast to all except sender.
    if (packet.hopsRemaining <= 0) return;

    final forwarded = MeshPacket(
      type: packet.type,
      messageId: packet.messageId,
      senderDeviceId: packet.senderDeviceId,
      senderNickname: packet.senderNickname,
      body: packet.body,
      createdAtMs: packet.createdAtMs,
      hopsRemaining: packet.hopsRemaining - 1,
      payload: packet.payload,
    );

    final bytes = Uint8List.fromList(utf8.encode(forwarded.encode()));
    await transport.broadcast(bytes, exceptPeerId: incoming.fromPeerId);
  }

  Future<void> _handleChatPacket(MeshPacket packet, String fromPeerId) async {
    final isMine = packet.senderDeviceId == localDeviceId;
    await database.insertMessage(
      ChatMessage(
        messageId: packet.messageId,
        senderDeviceId: packet.senderDeviceId,
        senderNickname: packet.senderNickname,
        body: packet.body,
        createdAtMs: packet.createdAtMs,
        hopsRemaining: packet.hopsRemaining,
        receivedFromPeerId: fromPeerId,
        isMine: isMine,
      ),
    );
    _messageAddedController.add(null);
  }

  Future<void> _handleSosPacket(MeshPacket packet, String fromPeerId) async {
    if (packet.payload == null) return;

    // Skip our own SOS that bounced back through the mesh.
    if (packet.senderDeviceId == localDeviceId) return;

    final beacon = SosBeacon.fromPayload(
      packet.payload!,
      senderDeviceId: packet.senderDeviceId,
      senderNickname: packet.senderNickname,
      timestampMs: packet.createdAtMs,
    );

    // If the beacon is "safe", remove from active beacons.
    if (beacon.level == SosLevel.safe) {
      await database.removeSosBeacon(beacon.senderDeviceId);
    } else {
      await database.upsertSosBeacon(beacon);
    }

    _sosReceivedController.add(beacon);
  }

  Future<void> _handleRescueConfirmPacket(MeshPacket packet) async {
    if (packet.payload == null) return;

    final targetDeviceId = packet.payload!['targetDeviceId'] as String?;
    if (targetDeviceId == null) return;

    // Only react if this confirmation is meant for us.
    if (targetDeviceId == localDeviceId) {
      _rescueConfirmController.add(packet.senderNickname);
    }
  }
}
