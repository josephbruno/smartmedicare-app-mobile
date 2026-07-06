import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'connectivity_notifier.dart';
import '../session/auth_session.dart';
import '../../data/local/sync_coordinator.dart';

/// Triggers catalog + offline invoice sync when connectivity is restored.
class OfflineSyncListener extends StatefulWidget {
  const OfflineSyncListener({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineSyncListener> createState() => _OfflineSyncListenerState();
}

class _OfflineSyncListenerState extends State<OfflineSyncListener> {
  bool? _wasOnline;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityNotifier>().isOnline;
    final auth = context.watch<AuthSession>();

    if (_wasOnline == false && online && auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SyncCoordinator>().onReconnect(auth.currentBranchId);
      });
    }
    _wasOnline = online;

    return widget.child;
  }
}
