/// Prescription Under category catalog item (same shape as treatment under).
class PrescriptionUnderCategoryItem {
  const PrescriptionUnderCategoryItem({
    required this.id,
    required this.slug,
    required this.label,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSystem = false,
  });

  factory PrescriptionUnderCategoryItem.fromJson(Map<String, dynamic> j) {
    return PrescriptionUnderCategoryItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      slug: j['slug']?.toString() ?? '',
      label: j['label']?.toString() ?? '',
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] == true || j['is_active'] == 1,
      isSystem: j['is_system'] == true || j['is_system'] == 1,
    );
  }

  final int id;
  final String slug;
  final String label;
  final int sortOrder;
  final bool isActive;
  final bool isSystem;
}

/// Prescription Under visit tabs — defaults are fallback; runtime uses API catalog.
class PrescriptionUnderCategory {
  static const oral = 'oral';
  static const topical = 'topical';
  static const injectable = 'injectable';
  static const supplements = 'supplements';
  static const chronic = 'chronic';
  static const unique = 'unique';

  static const keys = [
    oral,
    topical,
    injectable,
    supplements,
    chronic,
    unique,
  ];

  static const labels = {
    oral: 'Oral',
    topical: 'Topical',
    injectable: 'Injectable',
    supplements: 'Supplements',
    chronic: 'Chronic',
    unique: 'Unique',
  };

  static List<String> keysOf(List<PrescriptionUnderCategoryItem> catalog) =>
      catalog.map((c) => c.slug).where((s) => s.isNotEmpty).toList();

  static bool isValid(String? value, [List<PrescriptionUnderCategoryItem>? catalog]) {
    if (value == null || value.isEmpty) return false;
    if (catalog != null) {
      return catalog.any((c) => c.slug == value);
    }
    return keys.contains(value);
  }

  static String? normalize(String? value, [List<PrescriptionUnderCategoryItem>? catalog]) =>
      isValid(value, catalog) ? value : null;

  static String forVisit({
    String? snapshot,
    String? fromProduct,
  }) {
    if (snapshot != null && snapshot.isNotEmpty) return snapshot;
    if (fromProduct != null && fromProduct.isNotEmpty) return fromProduct;
    return unique;
  }

  static String labelOf(
    String? value, [
    List<PrescriptionUnderCategoryItem>? catalog,
  ]) {
    final slug = (value == null || value.isEmpty) ? unique : value;
    if (catalog != null) {
      for (final c in catalog) {
        if (c.slug == slug) return c.label;
      }
    }
    return labels[slug] ?? _titleCase(slug);
  }

  static String _titleCase(String slug) {
    return slug
        .split(RegExp(r'[_\-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  static List<MapEntry<String, List<T>>> groupBy<T>(
    Iterable<T> items,
    String? Function(T) categoryOf, {
    List<PrescriptionUnderCategoryItem>? catalog,
  }) {
    final order = catalog != null && catalog.isNotEmpty
        ? keysOf(catalog)
        : keys;
    final buckets = <String, List<T>>{
      for (final key in order) key: <T>[],
    };
    final extras = <String, List<T>>{};

    for (final item in items) {
      final key = forVisit(snapshot: categoryOf(item));
      if (buckets.containsKey(key)) {
        buckets[key]!.add(item);
      } else {
        extras.putIfAbsent(key, () => <T>[]).add(item);
      }
    }

    return [
      for (final key in order)
        if (buckets[key]!.isNotEmpty) MapEntry(key, buckets[key]!),
      for (final e in extras.entries)
        if (e.value.isNotEmpty) e,
    ];
  }
}
