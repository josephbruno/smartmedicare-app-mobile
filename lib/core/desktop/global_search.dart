import '../../app_services.dart';

class GlobalSearchResult {
  GlobalSearchResult({
    required this.label,
    required this.subtitle,
    required this.path,
    required this.kind,
  });

  final String label;
  final String subtitle;
  final String path;
  final String kind;
}

/// Lightweight cross-entity search for desktop command palette / top bar.
class GlobalSearch {
  GlobalSearch(this._services);

  final AppServices _services;

  Future<List<GlobalSearchResult>> search(String query, {int limit = 12}) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final results = <GlobalSearchResult>[];

    await Future.wait([
      _searchCustomers(q, results, limit),
      _searchInvoices(q, results, limit),
      _searchVisits(q, results, limit),
    ]);

    return results.take(limit).toList();
  }

  Future<void> _searchCustomers(String q, List<GlobalSearchResult> out, int limit) async {
    try {
      final r = await _services.customers.listPaginated(page: 1, perPage: 5, search: q);
      for (final c in r.items) {
        out.add(GlobalSearchResult(
          label: c.name,
          subtitle: '${c.phone}${c.city != null ? ' · ${c.city}' : ''}',
          path: '/customers/${c.id}',
          kind: 'Customer',
        ));
      }
    } catch (_) {}
  }

  Future<void> _searchInvoices(String q, List<GlobalSearchResult> out, int limit) async {
    try {
      final r = await _services.billing.listPaginated(page: 1, perPage: 5, search: q);
      for (final inv in r.items) {
        out.add(GlobalSearchResult(
          label: inv.invoiceNumber,
          subtitle: '${inv.customer?.name ?? 'Walk-in'} · ₹${inv.totalAmount.toStringAsFixed(2)}',
          path: '/invoices/${inv.id}',
          kind: 'Invoice',
        ));
      }
    } catch (_) {}
  }

  Future<void> _searchVisits(String q, List<GlobalSearchResult> out, int limit) async {
    try {
      final r = await _services.emr.listVisitsPaginated(page: 1, perPage: 5, search: q);
      for (final v in r.items) {
        out.add(GlobalSearchResult(
          label: v.visitNumber,
          subtitle: '${v.pet?.name ?? 'Pet'} · ${v.status}',
          path: '/emr/visits/${v.id}',
          kind: 'Visit',
        ));
      }
    } catch (_) {}
  }
}
