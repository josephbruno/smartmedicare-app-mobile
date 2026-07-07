import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/offline_invoice_queue.dart';
import '../../../data/local/sync_coordinator.dart';
import '../../../core/session/auth_session.dart';

/// Bottom sheet / dialog listing pending offline POS invoices.
class OfflineQueueSheet extends StatefulWidget {
  const OfflineQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => const OfflineQueueSheet(),
    );
  }

  @override
  State<OfflineQueueSheet> createState() => _OfflineQueueSheetState();
}

class _OfflineQueueSheetState extends State<OfflineQueueSheet> {
  List<OfflineQueueEntry> _entries = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final queue = context.read<OfflineInvoiceQueue>();
    final entries = await queue.pendingEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final branchId = context.read<AuthSession>().currentBranchId;
      await context.read<SyncCoordinator>().syncAll(branchId: branchId);
      await _load();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Offline invoices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_entries.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Sync now'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pending offline invoices.', textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final total = e.payload['items'] is List
                        ? 'Items: ${(e.payload['items'] as List).length}'
                        : '';
                    return ListTile(
                      leading: const Icon(Icons.receipt_outlined, color: AppTheme.warning),
                      title: Text('Offline ${e.offlineId.substring(0, 8)}…'),
                      subtitle: Text('${e.createdAt.substring(0, 16)} · $total'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
