import '../services/customer_service.dart';
import 'customer_local_dao.dart';
import 'sync_meta_dao.dart';

class CustomerSyncService {
  CustomerSyncService(this._api, this._dao, this._meta);

  final CustomerService _api;
  final CustomerLocalDao _dao;
  final SyncMetaDao _meta;

  static const metaKey = 'customers_sync_at';

  Future<int> syncAll() async {
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    var page = 1;
    var total = 0;

    while (true) {
      final result = await _api.listPaginated(page: page, perPage: 50);
      await _dao.upsertAll(result.items);
      total += result.items.length;
      final lastPage = result.meta?.lastPage ?? 1;
      if (page >= lastPage) break;
      page++;
    }

    await _meta.set(metaKey, syncedAt);
    return total;
  }
}
