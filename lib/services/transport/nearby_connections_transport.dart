import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../../models/peer_device.dart';
import 'mesh_transport.dart';

/// Android transport using Google Nearby Connections.
///
/// Nearby Connections can use Bluetooth, BLE, and Wi‑Fi/Wi‑Fi Direct under the hood.
/// This is a good fit for "offline" peer-to-peer messaging.
class NearbyConnectionsTransport implements MeshTransport {
  final _nearby = Nearby();

  static const String _serviceId = 'com.example.my_app';

  final _eventsController = StreamController<TransportEvent>.broadcast();
  final _incomingController = StreamController<IncomingBytes>.broadcast();

  String _localName = 'Me';
  bool _running = false;

  bool _discovering = false;
  bool _advertising = false;

  final Map<String, PeerDevice> _discoveredById = {};
  final Map<String, PeerDevice> _connectedById = {};

  @override
  Stream<TransportEvent> get events => _eventsController.stream;

  @override
  Stream<IncomingBytes> get incoming => _incomingController.stream;

  @override
  bool get isRunning => _running;

  @override
  List<PeerDevice> get discoveredPeers =>
      _discoveredById.values.toList(growable: false);

  @override
  List<PeerDevice> get connectedPeers =>
      _connectedById.values.toList(growable: false);

  @override
  Future<void> start({required String localName}) async {
    _localName = localName;
    _running = true;
    _eventsController.add(
      TransportLog('NearbyConnectionsTransport started as "$_localName"'),
    );
  }

  @override
  Future<void> startDiscovery() async {
    if (!_running || _discovering) return;

    _discovering = true;
    _discoveredById.clear();

    try {
      _eventsController.add(
        TransportLog('Starting discovery (serviceId: $_serviceId)…'),
      );
      await _nearby.startDiscovery(
        _localName,
        Strategy.P2P_CLUSTER,
        serviceId: _serviceId,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final peer = PeerDevice(
            peerId: endpointId,
            displayName: endpointName,
            isConnected: _connectedById.containsKey(endpointId),
            lastSeenMs: now,
          );
          _discoveredById[endpointId] = peer;
          _eventsController.add(PeerDiscovered(peer));
        },
        onEndpointLost: (endpointId) {
          final id = endpointId;
          if (id == null) return;
          _discoveredById.remove(id);
          _eventsController.add(PeerLost(id));
        },
      );

      _eventsController.add(const TransportLog('Discovery started'));
    } catch (e) {
      _eventsController.add(TransportLog('Discovery failed: $e'));
      _discovering = false;
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    _discovering = false;
    try {
      await _nearby.stopDiscovery();
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<void> startAdvertising() async {
    if (!_running || _advertising) return;

    _advertising = true;
    try {
      _eventsController.add(
        TransportLog('Starting advertising (serviceId: $_serviceId)…'),
      );
      await _nearby.startAdvertising(
        _localName,
        Strategy.P2P_CLUSTER,
        serviceId: _serviceId,
        onConnectionInitiated: (endpointId, connectionInfo) {
          // Auto-accept for demo purposes.
          _nearby.acceptConnection(
            endpointId,
            onPayLoadRecieved: (id, payload) {
              final bytes = _extractBytes(payload);
              if (bytes == null) return;
              _incomingController.add(
                IncomingBytes(fromPeerId: id, bytes: bytes),
              );
            },
            onPayloadTransferUpdate: (id, update) {},
          );
        },
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final name = _discoveredById[endpointId]?.displayName ?? endpointId;
            final peer = PeerDevice(
              peerId: endpointId,
              displayName: name,
              isConnected: true,
              lastSeenMs: now,
            );
            _connectedById[endpointId] = peer;
            _eventsController.add(PeerConnected(peer));
          } else {
            _eventsController.add(
              TransportLog('Connection to $endpointId failed: $status'),
            );
          }
        },
        onDisconnected: (endpointId) {
          _connectedById.remove(endpointId);
          _eventsController.add(PeerDisconnected(endpointId));
        },
      );

      _eventsController.add(const TransportLog('Advertising started'));
    } catch (e) {
      _eventsController.add(TransportLog('Advertising failed: $e'));
      _advertising = false;
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    _advertising = false;
    try {
      await _nearby.stopAdvertising();
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<void> requestConnection(String peerId) async {
    try {
      await _nearby.requestConnection(
        _localName,
        peerId,
        onConnectionInitiated: (endpointId, connectionInfo) {
          _nearby.acceptConnection(
            endpointId,
            onPayLoadRecieved: (id, payload) {
              final bytes = _extractBytes(payload);
              if (bytes == null) return;
              _incomingController.add(
                IncomingBytes(fromPeerId: id, bytes: bytes),
              );
            },
            onPayloadTransferUpdate: (id, update) {},
          );
        },
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final name = _discoveredById[endpointId]?.displayName ?? endpointId;
            final peer = PeerDevice(
              peerId: endpointId,
              displayName: name,
              isConnected: true,
              lastSeenMs: now,
            );
            _connectedById[endpointId] = peer;
            _eventsController.add(PeerConnected(peer));
          } else {
            _eventsController.add(
              TransportLog('Connection to $endpointId failed: $status'),
            );
          }
        },
        onDisconnected: (endpointId) {
          _connectedById.remove(endpointId);
          _eventsController.add(PeerDisconnected(endpointId));
        },
      );
    } catch (e) {
      _eventsController.add(TransportLog('requestConnection failed: $e'));
    }
  }

  @override
  Future<void> disconnect(String peerId) async {
    try {
      await _nearby.disconnectFromEndpoint(peerId);
    } catch (_) {
      // ignore
    }
    _connectedById.remove(peerId);
    _eventsController.add(PeerDisconnected(peerId));
  }

  @override
  Future<void> sendBytes(String peerId, Uint8List bytes) async {
    try {
      await _nearby.sendBytesPayload(peerId, bytes);
    } catch (e) {
      _eventsController.add(TransportLog('sendBytes failed: $e'));
    }
  }

  @override
  Future<void> broadcast(Uint8List bytes, {String? exceptPeerId}) async {
    for (final peer in _connectedById.values) {
      if (peer.peerId == exceptPeerId) continue;
      await sendBytes(peer.peerId, bytes);
    }
  }

  @override
  Future<void> stop() async {
    await stopDiscovery();
    await stopAdvertising();

    _running = false;
    _discoveredById.clear();
    _connectedById.clear();

    await _eventsController.close();
    await _incomingController.close();
  }

  Uint8List? _extractBytes(Payload payload) {
    try {
      if (payload.type == PayloadType.BYTES) {
        return payload.bytes;
      }

      // For completeness; we only use BYTES for chat messages.
      if (payload.type == PayloadType.FILE) {
        _eventsController.add(
          const TransportLog('FILE payload ignored in starter app.'),
        );
        return null;
      }

      if (payload.type == PayloadType.STREAM) {
        _eventsController.add(
          const TransportLog('STREAM payload ignored in starter app.'),
        );
        return null;
      }
    } catch (e) {
      _eventsController.add(TransportLog('Failed to parse payload: $e'));
    }
    return null;
  }
}
