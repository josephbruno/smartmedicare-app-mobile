class PaginationMeta {
  PaginationMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

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
