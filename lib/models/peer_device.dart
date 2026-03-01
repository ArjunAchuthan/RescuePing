class PeerDevice {
  const PeerDevice({
    required this.peerId,
    required this.displayName,
    required this.isConnected,
    required this.lastSeenMs,
  });

  final String peerId;
  final String displayName;
  final bool isConnected;
  final int lastSeenMs;

  PeerDevice copyWith({
    String? peerId,
    String? displayName,
    bool? isConnected,
    int? lastSeenMs,
  }) {
    return PeerDevice(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      isConnected: isConnected ?? this.isConnected,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    );
  }
}
