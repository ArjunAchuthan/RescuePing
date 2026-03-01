import 'dart:async';
import 'dart:typed_data';

import '../../models/peer_device.dart';

class IncomingBytes {
  const IncomingBytes({required this.fromPeerId, required this.bytes});

  final String fromPeerId;
  final Uint8List bytes;
}

/// High-level transport events the UI/relay layer cares about.
sealed class TransportEvent {
  const TransportEvent();
}

class PeerDiscovered extends TransportEvent {
  const PeerDiscovered(this.peer);
  final PeerDevice peer;
}

class PeerConnected extends TransportEvent {
  const PeerConnected(this.peer);
  final PeerDevice peer;
}

class PeerDisconnected extends TransportEvent {
  const PeerDisconnected(this.peerId);
  final String peerId;
}

class PeerLost extends TransportEvent {
  const PeerLost(this.peerId);
  final String peerId;
}

class TransportLog extends TransportEvent {
  const TransportLog(this.message);
  final String message;
}

/// Abstract P2P transport.
///
/// - Android: backed by Nearby Connections (Bluetooth + Wi‑Fi/Wi‑Fi Direct).
/// - Other platforms / no-hardware: simulation backend.
abstract class MeshTransport {
  Stream<TransportEvent> get events;
  Stream<IncomingBytes> get incoming;

  bool get isRunning;

  List<PeerDevice> get discoveredPeers;
  List<PeerDevice> get connectedPeers;

  Future<void> start({required String localName});

  /// Discovery is separated so you can run advertise-only or discover-only.
  Future<void> startDiscovery();
  Future<void> stopDiscovery();

  Future<void> startAdvertising();
  Future<void> stopAdvertising();

  Future<void> requestConnection(String peerId);
  Future<void> disconnect(String peerId);

  Future<void> sendBytes(String peerId, Uint8List bytes);

  Future<void> broadcast(Uint8List bytes, {String? exceptPeerId});

  Future<void> stop();
}
