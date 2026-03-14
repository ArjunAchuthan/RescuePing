import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../widgets/peer_tile.dart';
import 'chat_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _permissionsRequested = false;
  bool _hadMissingPermissions = false;

  late final _LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _LifecycleObserver(onResumed: _onResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // First time entering the screen: request permissions (Android) and start transport.
    if (!_permissionsRequested) {
      _permissionsRequested = true;
      Future.microtask(() async {
        await _requestPermissionsIfNeeded();
        if (!mounted) return;
        await context.read<AppState>().startTransport();
      });
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {

    // Request ALL permissions the Nearby Connections API needs.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission
          .location, // ACCESS_FINE_LOCATION — required on ALL Android versions
      Permission.nearbyWifiDevices,
    ].request();

    final bluetoothOk =
        (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
        (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
        (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false);

    final locationOk = (statuses[Permission.location]?.isGranted ?? false);

    final discoveryOk = bluetoothOk && locationOk;

    // Check if the Location Services toggle (GPS) is actually ON.
    final locationServiceOn =
        await Permission.locationWhenInUse.serviceStatus ==
        ServiceStatus.enabled;

    _hadMissingPermissions = !discoveryOk || !locationServiceOn;

    if (!mounted) return;

    if (!discoveryOk) {
      final permanentlyDenied = statuses.values.any(
        (s) => s.isPermanentlyDenied,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nearby discovery needs ALL Bluetooth + Location permissions. Please allow them to see other devices.',
          ),
          duration: const Duration(seconds: 6),
          action: permanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ),
      );
    } else if (!locationServiceOn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Turn ON Location Services (GPS toggle). Nearby Connections requires it for scanning.',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }

    debugPrint('Permission statuses: $statuses');
    debugPrint('Location service on: $locationServiceOn');
  }

  Future<void> _onResumed() async {
    if (!mounted) return;


    // If we previously detected missing permissions/services, re-check and restart transport.
    if (!_hadMissingPermissions) return;

    await _requestPermissionsIfNeeded();
    if (!mounted) return;

    final state = context.read<AppState>();

    // Restart transport to pick up newly granted permissions.
    await state.stopTransport();
    await state.startTransport();
  }

  void _openChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final connectedCount = state.peers.where((p) => p.isConnected).length;
    final discoveredCount = state.peers.length;
    final isRunning = state.transport?.isRunning == true;

    const transportLabel = 'Nearby Connections transport';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('RescuePing Mesh'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open Chat',
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF111E36),
                    scheme.surface,
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MeshHeroHeader(
                        nickname: state.nickname ?? '-',
                        transportLabel: transportLabel,
                        isRunning: isRunning,
                        isConnecting: state.isConnecting,
                        connectedCount: connectedCount,
                        discoveredCount: discoveredCount,
                        hopLimit: state.meshHopLimit,
                      ),
                      const SizedBox(height: 10),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(
                            Icons.hub_outlined,
                            color: scheme.primary,
                          ),
                          title: const Text('Pseudo-mesh forwarding'),
                          subtitle: Text(
                            'Broadcast → de-dupe → hop-limited forwarding.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: ExpansionTile(
                          title: const Text('Advanced'),
                          subtitle: Text(
                            'Transport + diagnostics',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          children: [
                            _TransportLogs(logs: state.transportLogs),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                        child: Row(
                          children: [
                            Text(
                              'Nearby Devices',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            if (isRunning && !state.isConnecting) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Scanning…',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.peers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRunning) ...[
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            Icon(
                              Icons.wifi_tethering_off,
                              size: 36,
                              color: scheme.onSurfaceVariant,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            isRunning
                                ? 'Searching for nearby devices…'
                                : 'Transport not running',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Make sure Bluetooth & Location are enabled on both phones.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: state.peers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final peer = state.peers[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: PeerTile(
                          peer: peer,
                          onTap: peer.isConnected
                              ? () => context.read<AppState>().disconnectPeer(
                                  peer.peerId,
                                )
                              : () => context.read<AppState>().connectToPeer(
                                  peer.peerId,
                                ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChat,
        label: const Text('Chat Room'),
        icon: const Icon(Icons.forum_outlined),
      ),
    );
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({required this.onResumed});

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

class _MeshHeroHeader extends StatelessWidget {
  const _MeshHeroHeader({
    required this.nickname,
    required this.transportLabel,
    required this.isRunning,
    required this.isConnecting,
    required this.connectedCount,
    required this.discoveredCount,
    required this.hopLimit,
  });

  final String nickname;
  final String transportLabel;
  final bool isRunning;
  final bool isConnecting;
  final int connectedCount;
  final int discoveredCount;
  final int hopLimit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1565C0).withValues(alpha: 0.15),
              const Color(0xFF111E36),
              scheme.surfaceContainerHighest,
            ],
          ),
          border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: CustomPaint(
                    painter: _MeshBackdropPainter(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        child: const Icon(Icons.wifi_tethering, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              transportLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        label: isRunning
                            ? (isConnecting ? 'Starting…' : 'Online')
                            : 'Offline',
                        color: isRunning ? scheme.primary : scheme.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(
                        label: '$connectedCount connected',
                        color: scheme.secondary,
                      ),
                      _StatusPill(
                        label: '$discoveredCount discovered',
                        color: scheme.tertiary,
                      ),
                      _StatusPill(
                        label: 'TTL $hopLimit hops',
                        color: scheme.primary,
                      ),
                      _StatusPill(label: 'De-dupe on', color: scheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeshBackdropPainter extends CustomPainter {
  _MeshBackdropPainter({this.color = const Color(0xFFFFFFFF)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final nodes = <Offset>[
      Offset(size.width * 0.12, size.height * 0.30),
      Offset(size.width * 0.32, size.height * 0.18),
      Offset(size.width * 0.55, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.18),
      Offset(size.width * 0.22, size.height * 0.62),
      Offset(size.width * 0.48, size.height * 0.68),
      Offset(size.width * 0.74, size.height * 0.62),
    ];

    // Links
    paint.color = color;
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], paint);
    }
    canvas.drawLine(nodes[1], nodes[4], paint);
    canvas.drawLine(nodes[2], nodes[5], paint);
    canvas.drawLine(nodes[3], nodes[6], paint);

    // Nodes
    paint.style = PaintingStyle.fill;
    for (final n in nodes) {
      canvas.drawCircle(n, 4.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TransportLogs extends StatelessWidget {
  const _TransportLogs({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (logs.isEmpty) {
      return Text(
        'No recent activity yet.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final recent = logs.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recent activity',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...recent.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• $l',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 115)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 89),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
    );
  }
}
