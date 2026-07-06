import '../services/billing_service.dart';
import 'offline_invoice_queue.dart';
import 'sync_coordinator.dart';

/// Enqueue offline invoices and sync when online.
class OfflineBillingCoordinator {
  OfflineBillingCoordinator(
    this._billing,
    this._queue,
  );

  final BillingService _billing;
  final OfflineInvoiceQueue _queue;

  Future<int> pendingCount() => _queue.pendingCount();

  Future<void> enqueuePayload(String offlineId, Map<String, dynamic> payload) {
    return _queue.enqueue(offlineId, payload);
  }

  /// POST `/invoices/sync-offline` and remove only successfully synced items.
  Future<List<OfflineSyncResult>> syncPending() async {
    final payloads = await _queue.pendingPayloads();
    if (payloads.isEmpty) return [];

    final raw = await _billing.syncOffline(payloads);
    final results = raw
        .whereType<Map>()
        .map((e) => OfflineSyncResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final syncedIds = results
        .where((r) => r.isSuccess && r.offlineId != null)
        .map((r) => r.offlineId!)
        .toList();
    await _queue.removeByOfflineIds(syncedIds);
    return results;
  }
}
