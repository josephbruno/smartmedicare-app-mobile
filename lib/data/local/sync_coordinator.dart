import 'dart:async';

import 'package:flutter/foundation.dart';

import 'customer_sync_service.dart';
import 'offline_billing_coordinator.dart';
import 'product_sync_service.dart';

/// Orchestrates catalog sync, offline invoice upload, and reconnect handling.
class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator({
    required ProductSyncService productSync,
    required CustomerSyncService customerSync,
    required OfflineBillingCoordinator billingCoordinator,
  })  : _productSync = productSync,
        _customerSync = customerSync,
        _billingCoordinator = billingCoordinator;

  final ProductSyncService _productSync;
  final CustomerSyncService _customerSync;
  final OfflineBillingCoordinator _billingCoordinator;

  bool _syncing = false;
  bool _posLoopActive = false;
  Timer? _posTimer;
  int? _posBranchId;
  final Set<int> _posFullSyncedBranches = {};
  String? _lastError;
  int _localProductCount = 0;

  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  int get localProductCount => _localProductCount;

  void startPosSyncLoop(int? branchId) {
    if (branchId == null) return;
    _posBranchId = branchId;
    if (_posLoopActive) {
      // Branch switched while POS is open — force a full rebuild.
      if (!_posFullSyncedBranches.contains(branchId)) {
        unawaited(_syncPosCatalog(branchId, forceFull: true));
      }
      return;
    }
    _posLoopActive = true;
    unawaited(_syncPosCatalog(branchId, forceFull: true));
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      final id = _posBranchId;
      if (id != null) unawaited(_syncPosCatalog(id));
    });
  }

  void stopPosSyncLoop() {
    _posLoopActive = false;
    _posTimer?.cancel();
    _posTimer = null;
  }

  Future<void> syncAll({int? branchId, bool forceFullCatalog = false}) async {
    if (_syncing) return;
    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final id = branchId ?? _posBranchId;
      if (id != null) {
        await _productSync.syncForBranch(id, forceFull: forceFullCatalog);
        if (forceFullCatalog) _posFullSyncedBranches.add(id);
        _localProductCount = await _productSync.localCount(id);
      }
      await _customerSync.syncAll();
      await _billingCoordinator.syncPending();
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> onReconnect(int? branchId) async {
    try {
      await syncAll(branchId: branchId, forceFullCatalog: true);
    } catch (_) {
      // Surface via lastError; callers may show snackbar.
    }
  }

  Future<void> _syncPosCatalog(int branchId, {bool forceFull = false}) async {
    if (_syncing) return;
    try {
      final doFull = forceFull || !_posFullSyncedBranches.contains(branchId);
      await _productSync.syncForBranch(branchId, forceFull: doFull);
      _posFullSyncedBranches.add(branchId);
      _localProductCount = await _productSync.localCount(branchId);
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPosSyncLoop();
    super.dispose();
  }
}

/// Typed result from offline invoice sync API.
class OfflineSyncResult {
  OfflineSyncResult({
    required this.offlineId,
    required this.status,
    this.invoiceId,
    this.message,
  });

  final String? offlineId;
  final String status;
  final int? invoiceId;
  final String? message;

  factory OfflineSyncResult.fromJson(Map<String, dynamic> j) => OfflineSyncResult(
        offlineId: j['offline_id']?.toString(),
        status: j['status']?.toString() ?? 'error',
        invoiceId: (j['invoice_id'] as num?)?.toInt(),
        message: j['message']?.toString(),
      );

  bool get isSuccess => status == 'created' || status == 'duplicate';
}
