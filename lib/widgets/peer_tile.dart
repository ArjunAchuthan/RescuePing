import 'package:flutter/material.dart';

import '../models/peer_device.dart';

class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.peer, required this.onTap});

  final PeerDevice peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final initials = _initials(peer.displayName);
    final avatarBg = peer.isConnected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final avatarFg = peer.isConnected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(peer.displayName),
      subtitle: Text(peer.peerId, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(peer.isConnected ? Icons.link_off : Icons.link),
        label: Text(peer.isConnected ? 'Disconnect' : 'Connect'),
      ),
      leading: CircleAvatar(
        backgroundColor: avatarBg,
        foregroundColor: avatarFg,
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}
