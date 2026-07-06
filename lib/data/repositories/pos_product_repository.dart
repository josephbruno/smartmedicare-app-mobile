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
    if (q.isEmpty) {
      return _dao.listRecent(branchId, limit: 50);
    }

    final local = await _dao.search(branchId, q, limit: 30);
    if (!online || local.length >= 15) return local;

    try {
      final remote = await _api.search(q);
      if (remote.isNotEmpty) {
        await _dao.upsertAll(remote, branchId);
        return _dao.search(branchId, q, limit: 30);
      }
    } catch (_) {
      // Keep local results when API is unreachable.
    }
    return local;
  }

  Future<Product?> findByBarcode(int branchId, String barcode, {required bool online}) async {
    final local = await _dao.findByBarcode(branchId, barcode);
    if (local != null || !online) return local;

    try {
      final remote = await _api.findByBarcode(barcode);
      if (remote != null) {
        await _dao.upsertAll([remote], branchId);
        return remote;
      }
    } catch (_) {}
    return null;
  }

  Future<int> localCount(int branchId) => _dao.countForBranch(branchId);
}
