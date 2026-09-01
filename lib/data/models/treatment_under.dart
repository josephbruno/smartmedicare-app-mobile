class TreatmentUnderCategoryItem {
  const TreatmentUnderCategoryItem({
    required this.id,
    required this.slug,
    required this.label,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSystem = false,
  });

  factory TreatmentUnderCategoryItem.fromJson(Map<String, dynamic> j) {
    return TreatmentUnderCategoryItem(
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

/// Treatment Under visit tabs — defaults are fallback; runtime uses API catalog.
class TreatmentUnderCategory {
  static const antibiotics = 'antibiotics';
  static const fluids = 'fluids';
  static const nsaids = 'nsaids';
  static const supportive = 'supportive';
  static const anesthetics = 'anesthetics';
  static const unique = 'unique';

  static const keys = [
    antibiotics,
    fluids,
    nsaids,
    supportive,
    anesthetics,
    unique,
  ];

  static const labels = {
    antibiotics: 'Antibiotics',
    fluids: 'Fluids',
    nsaids: 'NSAIDS',
    supportive: 'Supportive',
    anesthetics: 'Anesthetics',
    unique: 'Unique',
  };

  static List<String> keysOf(List<TreatmentUnderCategoryItem> catalog) =>
      catalog.map((c) => c.slug).where((s) => s.isNotEmpty).toList();

  static bool isValid(String? value, [List<TreatmentUnderCategoryItem>? catalog]) {
    if (value == null || value.isEmpty) return false;
    if (catalog != null) {
      return catalog.any((c) => c.slug == value);
    }
    return keys.contains(value);
  }

  static String? normalize(String? value, [List<TreatmentUnderCategoryItem>? catalog]) =>
      isValid(value, catalog) ? value : null;

  /// Prefer snapshot / product slug; fall back to Unique when missing.
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
    List<TreatmentUnderCategoryItem>? catalog,
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
    List<TreatmentUnderCategoryItem>? catalog,
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
