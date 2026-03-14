import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../models/peer_device.dart';
import '../models/sos_status.dart';
import '../models/user_profile.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, 'disaster_mesh_chat.db');

    final database = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (Database db, int version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
        await _migrateV3(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
        if (oldVersion < 3) {
          await _migrateV3(db);
        }
      },
    );

    _db = database;
    return database;
  }

  static Future<void> _createV1Tables(Database db) async {
    await db.execute(
      ''
      'CREATE TABLE peers('
      ' peer_id TEXT PRIMARY KEY,'
      ' display_name TEXT NOT NULL,'
      ' is_connected INTEGER NOT NULL,'
      ' last_seen_ms INTEGER NOT NULL'
      ')'
      '',
    );

    await db.execute(
      ''
      'CREATE TABLE messages('
      ' message_id TEXT PRIMARY KEY,'
      ' sender_device_id TEXT NOT NULL,'
      ' sender_nickname TEXT NOT NULL,'
      ' body TEXT NOT NULL,'
      ' created_at_ms INTEGER NOT NULL,'
      ' hops_remaining INTEGER NOT NULL,'
      ' received_from_peer_id TEXT,'
      ' is_mine INTEGER NOT NULL'
      ')'
      '',
    );

    await db.execute(
      ''
      'CREATE TABLE seen_messages('
      ' message_id TEXT PRIMARY KEY,'
      ' first_seen_ms INTEGER NOT NULL'
      ')'
      '',
    );

    await db.execute(
      'CREATE INDEX idx_messages_created_at ON messages(created_at_ms)',
    );
  }

  static Future<void> _createV2Tables(Database db) async {
    // Single-row table for the local user's emergency profile.
    await db.execute(
      ''
      'CREATE TABLE IF NOT EXISTS user_profile('
      ' id INTEGER PRIMARY KEY DEFAULT 1,'
      ' nickname TEXT NOT NULL,'
      ' blood_group TEXT NOT NULL DEFAULT \'\','
      ' medical_notes TEXT NOT NULL DEFAULT \'\','
      ' emergency_contact_name TEXT NOT NULL DEFAULT \'\','
      ' emergency_contact_phone TEXT NOT NULL DEFAULT \'\','
      ' people_count INTEGER NOT NULL DEFAULT 1,'
      ' role TEXT NOT NULL DEFAULT \'needHelp\''
      ')'
      '',
    );

    // SOS beacons received from (or sent by) devices on the mesh.
    await db.execute(
      ''
      'CREATE TABLE IF NOT EXISTS sos_beacons('
      ' sender_device_id TEXT PRIMARY KEY,'
      ' sender_nickname TEXT NOT NULL,'
      ' level TEXT NOT NULL,'
      ' message TEXT NOT NULL DEFAULT \'\','
      ' latitude REAL,'
      ' longitude REAL,'
      ' people_count INTEGER NOT NULL DEFAULT 1,'
      ' blood_group TEXT NOT NULL DEFAULT \'\','
      ' timestamp_ms INTEGER NOT NULL,'
      ' is_rescued INTEGER NOT NULL DEFAULT 0'
      ')'
      '',
    );
  }

  /// V3 migration: add role to user_profile and is_rescued to sos_beacons.
  static Future<void> _migrateV3(Database db) async {
    // Add role column to existing user_profile table.
    try {
      await db.execute(
        "ALTER TABLE user_profile ADD COLUMN role TEXT NOT NULL DEFAULT 'needHelp'",
      );
    } catch (_) {
      // Column may already exist (fresh install via onCreate).
    }

    // Add is_rescued column to existing sos_beacons table.
    try {
      await db.execute(
        'ALTER TABLE sos_beacons ADD COLUMN is_rescued INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {
      // Column may already exist.
    }
  }

  // ─── Peers ───────────────────────────────────────────────────────────

  Future<void> upsertPeer(PeerDevice peer) async {
    final database = await db;
    await database.insert('peers', {
      'peer_id': peer.peerId,
      'display_name': peer.displayName,
      'is_connected': peer.isConnected ? 1 : 0,
      'last_seen_ms': peer.lastSeenMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PeerDevice>> listPeers() async {
    final database = await db;
    final rows = await database.query(
      'peers',
      orderBy: 'is_connected DESC, last_seen_ms DESC',
    );

    return rows
        .map(
          (r) => PeerDevice(
            peerId: r['peer_id'] as String,
            displayName: r['display_name'] as String,
            isConnected: (r['is_connected'] as int) == 1,
            lastSeenMs: (r['last_seen_ms'] as int),
          ),
        )
        .toList();
  }

  Future<void> clearPeers() async {
    final database = await db;
    await database.delete('peers');
  }

  // ─── Messages ────────────────────────────────────────────────────────

  Future<bool> markSeenMessageId(String messageId) async {
    final database = await db;
    final inserted = await database.insert('seen_messages', {
      'message_id': messageId,
      'first_seen_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return inserted != 0;
  }

  Future<void> insertMessage(ChatMessage message) async {
    final database = await db;
    await database.insert('messages', {
      'message_id': message.messageId,
      'sender_device_id': message.senderDeviceId,
      'sender_nickname': message.senderNickname,
      'body': message.body,
      'created_at_ms': message.createdAtMs,
      'hops_remaining': message.hopsRemaining,
      'received_from_peer_id': message.receivedFromPeerId,
      'is_mine': message.isMine ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<ChatMessage>> listMessages({int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      'messages',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );

    return rows
        .map(
          (r) => ChatMessage(
            messageId: r['message_id'] as String,
            senderDeviceId: r['sender_device_id'] as String,
            senderNickname: r['sender_nickname'] as String,
            body: r['body'] as String,
            createdAtMs: r['created_at_ms'] as int,
            hopsRemaining: r['hops_remaining'] as int,
            receivedFromPeerId: r['received_from_peer_id'] as String?,
            isMine: (r['is_mine'] as int) == 1,
          ),
        )
        .toList();
  }

  /// Delete messages older than [maxAge] (default 3 days).
  Future<int> deleteExpiredMessages({
    Duration maxAge = const Duration(days: 3),
  }) async {
    final database = await db;
    final cutoffMs =
        DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    return database.delete(
      'messages',
      where: 'created_at_ms < ?',
      whereArgs: [cutoffMs],
    );
  }

  // ─── User profile ───────────────────────────────────────────────────

  Future<void> saveProfile(UserProfile profile) async {
    final database = await db;
    await database.insert('user_profile', {
      'id': 1,
      'nickname': profile.nickname,
      'blood_group': profile.bloodGroup,
      'medical_notes': profile.medicalNotes,
      'emergency_contact_name': profile.emergencyContactName,
      'emergency_contact_phone': profile.emergencyContactPhone,
      'people_count': profile.peopleCount,
      'role': profile.role.wire,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserProfile?> loadProfile() async {
    final database = await db;
    final rows = await database.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;

    final r = rows.first;
    return UserProfile(
      nickname: r['nickname'] as String,
      role: UserRole.fromWire((r['role'] as String?) ?? 'needHelp'),
      bloodGroup: (r['blood_group'] as String?) ?? '',
      medicalNotes: (r['medical_notes'] as String?) ?? '',
      emergencyContactName: (r['emergency_contact_name'] as String?) ?? '',
      emergencyContactPhone: (r['emergency_contact_phone'] as String?) ?? '',
      peopleCount: (r['people_count'] as int?) ?? 1,
    );
  }

  /// Delete the local user profile (post-rescue cleanup).
  Future<void> deleteProfile() async {
    final database = await db;
    await database.delete('user_profile');
  }

  /// Wipe all user-specific data (for post-rescue full reset).
  Future<void> clearAllUserData() async {
    final database = await db;
    await database.delete('user_profile');
    await database.delete('sos_beacons');
    await database.delete('messages');
    await database.delete('seen_messages');
    await database.delete('peers');
  }

  // ─── SOS beacons ────────────────────────────────────────────────────

  Future<void> upsertSosBeacon(SosBeacon beacon) async {
    final database = await db;
    await database.insert('sos_beacons', {
      'sender_device_id': beacon.senderDeviceId,
      'sender_nickname': beacon.senderNickname,
      'level': beacon.level.wire,
      'message': beacon.message,
      'latitude': beacon.latitude,
      'longitude': beacon.longitude,
      'people_count': beacon.peopleCount,
      'blood_group': beacon.bloodGroup,
      'timestamp_ms': beacon.timestampMs,
      'is_rescued': beacon.isRescued ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SosBeacon>> listActiveBeacons() async {
    final database = await db;
    final rows = await database.query(
      'sos_beacons',
      where: 'is_rescued = 0',
      orderBy: 'timestamp_ms DESC',
    );
    return rows.map((r) {
      return SosBeacon(
        senderDeviceId: r['sender_device_id'] as String,
        senderNickname: r['sender_nickname'] as String,
        level: SosLevel.fromWire(r['level'] as String),
        message: (r['message'] as String?) ?? '',
        latitude: r['latitude'] as double?,
        longitude: r['longitude'] as double?,
        peopleCount: (r['people_count'] as int?) ?? 1,
        bloodGroup: (r['blood_group'] as String?) ?? '',
        timestampMs: r['timestamp_ms'] as int,
        isRescued: (r['is_rescued'] as int?) == 1,
      );
    }).toList();
  }

  /// Remove beacons older than [maxAgeMs] (default 1 hour).
  Future<void> clearExpiredBeacons({int maxAgeMs = 3600000}) async {
    final database = await db;
    final cutoff = DateTime.now().millisecondsSinceEpoch - maxAgeMs;
    await database.delete(
      'sos_beacons',
      where: 'timestamp_ms < ?',
      whereArgs: [cutoff],
    );
  }

  /// Remove a specific beacon (e.g. when sender cancels SOS).
  Future<void> removeSosBeacon(String senderDeviceId) async {
    final database = await db;
    await database.delete(
      'sos_beacons',
      where: 'sender_device_id = ?',
      whereArgs: [senderDeviceId],
    );
  }

  /// Mark a beacon as rescued.
  Future<void> markBeaconRescued(String senderDeviceId) async {
    final database = await db;
    await database.update(
      'sos_beacons',
      {'is_rescued': 1},
      where: 'sender_device_id = ?',
      whereArgs: [senderDeviceId],
    );
  }

  Future<void> close() async {
    final database = _db;
    _db = null;
    await database?.close();
  }
}
