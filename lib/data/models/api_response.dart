class PaginationMeta {
  PaginationMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    this.raw = const {},
  });

  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  /// The full API `meta` object (e.g. list `stats` for KPI cards).
  final Map<String, dynamic> raw;

  /// `meta.stats` when the list was requested with `with_stats: 1`.
  Map<String, dynamic>? get stats =>
      raw['stats'] is Map ? Map<String, dynamic>.from(raw['stats'] as Map) : null;

  factory PaginationMeta.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return PaginationMeta(
        total: 0,
        perPage: 15,
        currentPage: 1,
        lastPage: 1,
      );
    }
    return PaginationMeta(
      total: (j['total'] as num?)?.toInt() ?? 0,
      perPage: (j['per_page'] as num?)?.toInt() ?? 15,
      currentPage: (j['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (j['last_page'] as num?)?.toInt() ?? 1,
      raw: j,
    );
  }
}

class ApiEnvelope<T> {
  ApiEnvelope({
    required this.success,
    this.message,
    required this.data,
    this.meta,
    this.errors,
  });

  final bool success;
  final String? message;
  final T data;
  final PaginationMeta? meta;
  final Map<String, List<String>>? errors;

  static Map<String, dynamic> asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }
}

/// Read-only helpers over a list response's `meta` for KPI cards
/// (`meta.summary`, `meta.stats.change`, `meta.stats.series`).
class PaginationMetaView {
  const PaginationMetaView([this.meta]);

  final PaginationMeta? meta;

  int get total => meta?.total ?? 0;

  Map<String, dynamic> get _raw => meta?.raw ?? const {};

  Map<String, dynamic>? get stats => meta?.stats;

  double summaryNum(String key, {String? fallback}) {
    final s = _raw['summary'];
    if (s is! Map) return 0;
    final v = s[key] ?? (fallback == null ? null : s[fallback]);
    return (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  }

  /// `stats.<key>` as a number (0 when missing).
  double stat(String key) {
    final v = stats?[key];
    return (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  }

  /// `stats.change.<key>` (or `stats.change` when it is a number).
  num? change([String? key]) {
    final c = stats?['change'];
    if (c is num) return key == null ? c : null;
    if (c is Map && key != null) {
      final v = c[key];
      return v is num ? v : num.tryParse('$v');
    }
    return null;
  }

  /// `stats.series.<key>`, optionally only the last [last] points.
  List<double> series(String key, {int? last}) {
    final s = stats?['series'];
    if (s is! Map || s[key] is! List) return const [];
    final list = (s[key] as List).map((e) => (e is num) ? e.toDouble() : 0.0).toList();
    if (last != null && list.length > last) return list.sublist(list.length - last);
    return list;
  }
}
