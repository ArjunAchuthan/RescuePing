/// Severity level for an SOS alert.
enum SosLevel {
  safe,
  needHelp,
  injured,
  trapped;

  String get label {
    switch (this) {
      case SosLevel.safe:
        return 'Safe';
      case SosLevel.needHelp:
        return 'Need Help';
      case SosLevel.injured:
        return 'Injured';
      case SosLevel.trapped:
        return 'Trapped';
    }
  }

  /// Wire-format string used in mesh packets.
  String get wire => name;

  static SosLevel fromWire(String value) {
    return SosLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SosLevel.needHelp,
    );
  }
}

/// An SOS beacon received from (or sent by) a device on the mesh.
class SosBeacon {
  const SosBeacon({
    required this.senderDeviceId,
    required this.senderNickname,
    required this.level,
    this.message = '',
    this.latitude,
    this.longitude,
    this.peopleCount = 1,
    this.bloodGroup = '',
    required this.timestampMs,
    this.isRescued = false,
  });

  final String senderDeviceId;
  final String senderNickname;
  final SosLevel level;

  /// Optional free-text message from the sender.
  final String message;

  /// GPS coordinates (null if location unavailable).
  final double? latitude;
  final double? longitude;

  /// How many people are at that location.
  final int peopleCount;

  final String bloodGroup;

  /// Epoch ms when the SOS was created.
  final int timestampMs;

  /// Whether this person has been rescued.
  final bool isRescued;

  bool get hasLocation => latitude != null && longitude != null;

  SosBeacon copyWith({
    String? senderDeviceId,
    String? senderNickname,
    SosLevel? level,
    String? message,
    double? latitude,
    double? longitude,
    int? peopleCount,
    String? bloodGroup,
    int? timestampMs,
    bool? isRescued,
  }) {
    return SosBeacon(
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      senderNickname: senderNickname ?? this.senderNickname,
      level: level ?? this.level,
      message: message ?? this.message,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      peopleCount: peopleCount ?? this.peopleCount,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      timestampMs: timestampMs ?? this.timestampMs,
      isRescued: isRescued ?? this.isRescued,
    );
  }

  Map<String, Object?> toPayload() => {
    'level': level.wire,
    'message': message,
    'lat': latitude,
    'lng': longitude,
    'peopleCount': peopleCount,
    'bloodGroup': bloodGroup,
  };

  static SosBeacon fromPayload(
    Map<String, Object?> payload, {
    required String senderDeviceId,
    required String senderNickname,
    required int timestampMs,
  }) {
    return SosBeacon(
      senderDeviceId: senderDeviceId,
      senderNickname: senderNickname,
      level: SosLevel.fromWire((payload['level'] as String?) ?? 'needHelp'),
      message: (payload['message'] as String?) ?? '',
      latitude: (payload['lat'] as num?)?.toDouble(),
      longitude: (payload['lng'] as num?)?.toDouble(),
      peopleCount: (payload['peopleCount'] as num?)?.toInt() ?? 1,
      bloodGroup: (payload['bloodGroup'] as String?) ?? '',
      timestampMs: timestampMs,
    );
  }
}
