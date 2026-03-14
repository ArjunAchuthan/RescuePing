import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/peer_device.dart';
import '../models/sos_status.dart';
import '../models/user_profile.dart';
import 'location_service.dart';
import 'relay/message_relay_manager.dart';
import 'transport/mesh_transport.dart';
import 'transport/nearby_connections_transport.dart';

class AppState extends ChangeNotifier {
  AppState();

  static const _prefsNicknameKey = 'nickname';
  static const _prefsDeviceIdKey = 'deviceId';

  static const int _defaultMeshHopLimit = 6;

  /// Auto-stop discovery after this many ms of no new peers. (Battery saving)
  static const int _discoveryTimeoutMs = 60000;

  final AppDatabase _db = AppDatabase.instance;
  final LocationService _location = LocationService();

  SharedPreferences? _prefs;

  String? _nickname;
  String? _deviceId;

  MeshTransport? _transport;
  MessageRelayManager? _relay;

  final List<String> _transportLogs = <String>[];

  List<PeerDevice> _peers = const [];
  List<ChatMessage> _messages = const [];

  // ─── Profile ─────────────────────────────────────────────────────
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  // ─── SOS state ───────────────────────────────────────────────────
  SosLevel _currentSosLevel = SosLevel.safe;
  SosLevel get currentSosLevel => _currentSosLevel;
  bool get isSosActive => _currentSosLevel != SosLevel.safe;

  List<SosBeacon> _nearbyBeacons = const [];
  List<SosBeacon> get nearbyBeacons => _nearbyBeacons;

  /// Only non-safe beacons from OTHER devices (active alerts).
  List<SosBeacon> get activeAlerts =>
      _nearbyBeacons
          .where((b) => b.level != SosLevel.safe && b.senderDeviceId != _deviceId)
          .toList();

  StreamSubscription<TransportEvent>? _transportEventsSub;
  StreamSubscription<void>? _messageAddedSub;
  StreamSubscription<SosBeacon>? _sosReceivedSub;
  StreamSubscription<String>? _rescueConfirmSub;
  Timer? _discoveryTimer;

  bool _isInitialized = false;
  bool _isConnecting = false;

  bool get isInitialized => _isInitialized;
  bool get isConnecting => _isConnecting;

  String? get nickname => _nickname;
  String? get deviceId => _deviceId;

  MeshTransport? get transport => _transport;

  int get meshHopLimit => _relay?.defaultHopLimit ?? _defaultMeshHopLimit;

  List<String> get transportLogs => List.unmodifiable(_transportLogs);

  List<PeerDevice> get peers => _peers;
  List<ChatMessage> get messages => _messages;

  /// The role of the current user.
  UserRole get userRole => _profile?.role ?? UserRole.needHelp;

  /// Stream for the UI to listen to rescue confirmations.
  final _rescueConfirmUiController = StreamController<String>.broadcast();
  Stream<String> get rescueConfirmReceived => _rescueConfirmUiController.stream;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _nickname = _prefs!.getString(_prefsNicknameKey);
    _deviceId = _prefs!.getString(_prefsDeviceIdKey);

    // Create a stable device id once.
    _deviceId ??= DateTime.now().microsecondsSinceEpoch.toString();
    await _prefs!.setString(_prefsDeviceIdKey, _deviceId!);

    // Load profile from DB.
    _profile = await _db.loadProfile();
    _nickname ??= _profile?.nickname;

    // Load existing SOS beacons.
    await _db.clearExpiredBeacons();
    _nearbyBeacons = await _db.listActiveBeacons();

    // Housekeeping: delete chat messages older than 3 days.
    await _db.deleteExpiredMessages();

    await _refreshFromDb();

    _isInitialized = true;
    notifyListeners();
  }

  // ─── Profile ─────────────────────────────────────────────────────

  Future<void> setNickname(String nickname) async {
    _nickname = nickname.trim();
    await _prefs!.setString(_prefsNicknameKey, _nickname!);
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    _nickname = profile.nickname;
    await _prefs!.setString(_prefsNicknameKey, profile.nickname);
    await _db.saveProfile(profile);

    // Keep the relay in sync so new messages use the updated nickname.
    _relay?.localNickname = profile.nickname;

    notifyListeners();
  }

  // ─── SOS ─────────────────────────────────────────────────────────

  /// Send an SOS alert. Grabs GPS once, then broadcasts over the mesh.
  Future<void> alertOthers({
    SosLevel level = SosLevel.needHelp,
    String message = '',
  }) async {
    _currentSosLevel = level;
    notifyListeners();

    // Grab GPS once (battery efficient).
    final pos = await _location.getLocationOnce();

    final beacon = SosBeacon(
      senderDeviceId: _deviceId!,
      senderNickname: _nickname ?? 'Unknown',
      level: level,
      message: message,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      peopleCount: _profile?.peopleCount ?? 1,
      bloodGroup: _profile?.bloodGroup ?? '',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    final relay = _relay;
    if (relay != null) {
      await relay.sendSosBeacon(beacon);
    } else {
      // Not connected yet — still persist locally.
      await _db.upsertSosBeacon(beacon);
    }

    await _refreshBeacons();
  }

  /// Cancel the SOS alert. Broadcasts a "safe" status.
  Future<void> cancelAlert() async {
    _currentSosLevel = SosLevel.safe;
    notifyListeners();

    await _db.removeSosBeacon(_deviceId!);

    final relay = _relay;
    if (relay != null) {
      final beacon = SosBeacon(
        senderDeviceId: _deviceId!,
        senderNickname: _nickname ?? 'Unknown',
        level: SosLevel.safe,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      await relay.sendSosBeacon(beacon);
    }

    await _refreshBeacons();
  }

  // ─── Rescue confirmation ─────────────────────────────────────────

  /// Rescuer marks a trapped person as rescued. Sends a confirm packet.
  Future<void> markAsRescued(String targetDeviceId) async {
    final relay = _relay;
    if (relay != null) {
      await relay.sendRescueConfirm(targetDeviceId);
    }
    // Also mark locally so it disappears from the rescuer's list.
    await _db.markBeaconRescued(targetDeviceId);
    await _refreshBeacons();
  }

  /// Trapped person accepts rescue. Cancels SOS, wipes profile, resets app.
  Future<void> confirmRescued() async {
    await cancelAlert();
    await _db.clearAllUserData();
    _profile = null;
    _nickname = null;
    await _prefs!.remove(_prefsNicknameKey);
    notifyListeners();
  }

  /// Full reset: wipe all data and return to initial state.
  Future<void> resetApp() async {
    await stopTransport();
    await _db.clearAllUserData();
    _profile = null;
    _nickname = null;
    _currentSosLevel = SosLevel.safe;
    _nearbyBeacons = const [];
    _peers = const [];
    _messages = const [];
    await _prefs!.remove(_prefsNicknameKey);
    notifyListeners();
  }

  // ─── Transport ───────────────────────────────────────────────────

  Future<void> startTransport() async {
    if (_nickname == null || _nickname!.isEmpty) return;

    _isConnecting = true;
    notifyListeners();

    await stopTransport();

    // Clear stale peer records so we only show freshly discovered devices.
    await _db.clearPeers();

    // Use the Nearby Connections transport (Android-only).
    final MeshTransport transport = NearbyConnectionsTransport();

    _transport = transport;
    await transport.start(localName: _nickname!);

    _addTransportLog('Starting mesh transport…');

    _transportEventsSub = transport.events.listen((event) async {
      if (event is TransportLog) {
        _addTransportLog(event.message);
      } else if (event is PeerDiscovered) {
        _addTransportLog('Discovered ${event.peer.displayName}');
        _resetDiscoveryTimer(); // Reset battery timer on new peer.
      } else if (event is PeerConnected) {
        _addTransportLog('Connected to ${event.peer.displayName}');
      } else if (event is PeerDisconnected) {
        _addTransportLog('Disconnected from ${event.peerId}');
      } else if (event is PeerLost) {
        _addTransportLog('Lost ${event.peerId}');
      }

      // Keep the peers table in sync.
      await _refreshPeersFromTransport();
    });

    _relay = MessageRelayManager(
      database: _db,
      transport: transport,
      localDeviceId: _deviceId!,
      localNickname: _nickname!,
      defaultHopLimit: _defaultMeshHopLimit,
    );

    await _relay!.start();
    _messageAddedSub = _relay!.messageAdded.listen((_) async {
      await _refreshMessagesFromDb();
    });
    _sosReceivedSub = _relay!.sosReceived.listen((_) async {
      await _refreshBeacons();
    });
    _rescueConfirmSub = _relay!.rescueConfirmReceived.listen((rescuerName) {
      _rescueConfirmUiController.add(rescuerName);
    });

    // For a cluster mesh, we typically advertise and discover simultaneously.
    await transport.startAdvertising();
    await transport.startDiscovery();

    _addTransportLog('Advertising + discovery started');
    _resetDiscoveryTimer();

    await _refreshPeersFromTransport();
    _isConnecting = false;
    notifyListeners();
  }

  Future<void> stopTransport() async {
    _isConnecting = false;

    _addTransportLog('Stopping transport…');

    _discoveryTimer?.cancel();
    _discoveryTimer = null;

    await _transportEventsSub?.cancel();
    _transportEventsSub = null;

    await _messageAddedSub?.cancel();
    _messageAddedSub = null;

    await _sosReceivedSub?.cancel();
    _sosReceivedSub = null;

    await _rescueConfirmSub?.cancel();
    _rescueConfirmSub = null;

    await _relay?.stop();
    _relay = null;

    final t = _transport;
    _transport = null;
    if (t != null) {
      await t.stop();
    }

    await _refreshPeersFromTransport();
    notifyListeners();
  }

  /// Auto-stop discovery after [_discoveryTimeoutMs] of no new peers to
  /// save battery. Advertising continues so others can still find us.
  void _resetDiscoveryTimer() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(
      Duration(milliseconds: _discoveryTimeoutMs),
      () async {
        final t = _transport;
        if (t != null && t.isRunning) {
          await t.stopDiscovery();
          _addTransportLog('Discovery paused (battery saving)');
        }
      },
    );
  }

  /// Manually restart discovery (user-triggered re-scan).
  Future<void> restartDiscovery() async {
    final t = _transport;
    if (t == null || !t.isRunning) return;
    await t.startDiscovery();
    _addTransportLog('Discovery restarted');
    _resetDiscoveryTimer();
  }

  void _addTransportLog(String message) {
    final stamped = message;
    _transportLogs.insert(0, stamped);
    const max = 50;
    if (_transportLogs.length > max) {
      _transportLogs.removeRange(max, _transportLogs.length);
    }
    notifyListeners();
  }

  Future<void> connectToPeer(String peerId) async {
    final t = _transport;
    if (t == null) return;
    await t.requestConnection(peerId);
    await _refreshPeersFromTransport();
  }

  Future<void> disconnectPeer(String peerId) async {
    final t = _transport;
    if (t == null) return;
    await t.disconnect(peerId);
    await _refreshPeersFromTransport();
  }

  Future<void> sendMessage(String body) async {
    final relay = _relay;
    if (relay == null) return;
    await relay.sendLocalMessage(body.trim());
    await _refreshMessagesFromDb();
  }

  // ─── Refresh helpers ─────────────────────────────────────────────

  Future<void> _refreshFromDb() async {
    await _refreshPeersFromDb();
    await _refreshMessagesFromDb();
  }

  Future<void> _refreshPeersFromDb() async {
    _peers = await _db.listPeers();
  }

  Future<void> _refreshMessagesFromDb() async {
    _messages = await _db.listMessages(limit: 300);
    notifyListeners();
  }

  Future<void> _refreshBeacons() async {
    await _db.clearExpiredBeacons();
    final all = await _db.listActiveBeacons();
    // Exclude our own beacon — we already show our SOS status separately.
    _nearbyBeacons = all.where((b) => b.senderDeviceId != _deviceId).toList();
    notifyListeners();
  }

  Future<void> _refreshPeersFromTransport() async {
    final t = _transport;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Persist discovered + connected peers.
    if (t != null) {
      for (final p in t.discoveredPeers) {
        await _db.upsertPeer(p.copyWith(lastSeenMs: now));
      }
      for (final p in t.connectedPeers) {
        await _db.upsertPeer(p.copyWith(isConnected: true, lastSeenMs: now));
      }
    }

    _peers = await _db.listPeers();
    notifyListeners();
  }
}
