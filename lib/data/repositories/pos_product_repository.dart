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

    // Empty browse: when online, rebuild local catalog from the live POS API
    // and prune anything the server no longer returns.
    if (q.isEmpty) {
      if (online) {
        try {
          await _refreshCatalogFromServer(branchId);
        } catch (_) {
          // Fall back to local catalog.
        }
      }
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

  /// Pulls every POS page and removes local products missing from the server.
  Future<void> _refreshCatalogFromServer(int branchId) async {
    final keepIds = <int>{};
    var page = 1;
    while (true) {
      final result = await _api.posPaginated(page: page, perPage: 50);
      if (result.items.isNotEmpty) {
        await _dao.upsertAll(result.items, branchId);
        keepIds.addAll(result.items.map((p) => p.id));
      }
      final lastPage = result.meta?.lastPage ?? 1;
      if (page >= lastPage) break;
      page++;
    }
    await _dao.pruneBranchExcept(branchId, keepIds);
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

  Future<int> localCount(int branchId) => _dao.countForBranch(branchId);
}
