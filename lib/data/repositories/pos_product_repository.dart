import '../models/product.dart';
import '../services/product_service.dart';
import '../local/product_local_dao.dart';

/// Offline-first product lookup for POS.
class PosProductRepository {
  PosProductRepository(this._api, this._dao);

  final ProductService _api;
  final ProductLocalDao _dao;

  Future<List<Product>> search(
    int branchId,
    String term, {
    required bool online,
  }) async {
    final q = term.trim();

    // Empty browse: local only. Full catalog sync is owned by SyncCoordinator /
    // ProductSyncService so POS open does not page /products/pos repeatedly.
    if (q.isEmpty) {
      return _dao.listRecent(branchId, limit: 50);
    }

    // Online search: always prefer API so price/name/active changes show up.
    if (online) {
      try {
        final remote = await _api.search(q);
        if (remote.isNotEmpty) {
          await _dao.upsertAll(remote, branchId);
          return remote.take(30).toList();
        }
        // Empty API result — do not fall back to stale local matches for the
        // same query; return empty so deleted products don't reappear.
        return const [];
      } catch (_) {
        // Network failure — use local.
      }
    }

    return _dao.search(branchId, q, limit: 30);
  }

  Future<Product?> findByBarcode(int branchId, String barcode, {required bool online}) async {
    if (online) {
      try {
        final remote = await _api.findByBarcode(barcode);
        if (remote != null) {
          await _dao.upsertAll([remote], branchId);
          return remote.isActive ? remote : null;
        }
        return null;
      } catch (_) {
        // Fall through to local.
      }
    }

    return _dao.findByBarcode(branchId, barcode);
  }

  /// Local POS catalog lookup (includes synced [Product.currentStock]).
  Future<Product?> findById(int branchId, int productId) =>
      _dao.findById(branchId, productId);

  Future<int> localCount(int branchId) => _dao.countForBranch(branchId);
}
