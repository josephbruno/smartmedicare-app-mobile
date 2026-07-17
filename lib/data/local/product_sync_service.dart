import '../services/product_service.dart';
import 'product_local_dao.dart';
import 'sync_meta_dao.dart';

/// Downloads POS catalog into SQLite (full paginated + delta).
class ProductSyncService {
  ProductSyncService(this._api, this._dao, this._meta);

  final ProductService _api;
  final ProductLocalDao _dao;
  final SyncMetaDao _meta;

  static String metaKey(int branchId) => 'products_sync_at_$branchId';

  Future<int> syncForBranch(int branchId, {bool forceFull = false}) async {
    final key = metaKey(branchId);
    final since = forceFull ? null : await _meta.get(key);
    final syncedAt = DateTime.now().toUtc().toIso8601String();

    if (since == null) {
      final keepIds = <int>{};
      var page = 1;
      var total = 0;
      while (true) {
        final result = await _api.posPaginated(page: page, perPage: 50);
        await _dao.upsertAll(result.items, branchId);
        keepIds.addAll(result.items.map((p) => p.id));
        total += result.items.length;
        final lastPage = result.meta?.lastPage ?? 1;
        if (page >= lastPage) break;
        page++;
      }
      // Drop local rows that no longer exist on the server.
      await _dao.pruneBranchExcept(branchId, keepIds);
      await _meta.set(key, syncedAt);
      return total;
    }

    final delta = await _api.posSync(since: since);
    if (delta.isNotEmpty) {
      await _dao.upsertAll(delta, branchId);
      // Soft-deleted / inactive products stay in SQLite but are filtered out of POS.
    }
    await _meta.set(key, syncedAt);
    return delta.length;
  }

  Future<int> localCount(int branchId) => _dao.countForBranch(branchId);
}
