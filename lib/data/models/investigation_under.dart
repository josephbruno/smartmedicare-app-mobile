class InvestigationUnderCategoryItem {
  const InvestigationUnderCategoryItem({
    required this.id,
    required this.slug,
    required this.label,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSystem = false,
  });

  factory InvestigationUnderCategoryItem.fromJson(Map<String, dynamic> j) {
    return InvestigationUnderCategoryItem(
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

/// Investigation visit tabs — defaults are fallback; runtime uses API catalog.
class InvestigationUnderCategory {
  static const blood = 'blood';
  static const imaging = 'imaging';
  static const lab = 'lab';
  static const unique = 'unique';

  static const keys = [
    blood,
    imaging,
    lab,
    unique,
  ];

  static const labels = {
    blood: 'Blood',
    imaging: 'Imaging',
    lab: 'Lab',
    unique: 'Unique',
  };

  static List<String> keysOf(List<InvestigationUnderCategoryItem> catalog) =>
      catalog.map((c) => c.slug).where((s) => s.isNotEmpty).toList();

  static bool isValid(
    String? value, [
    List<InvestigationUnderCategoryItem>? catalog,
  ]) {
    if (value == null || value.isEmpty) return false;
    if (catalog != null) {
      return catalog.any((c) => c.slug == value);
    }
    return keys.contains(value);
  }

  static String? normalize(
    String? value, [
    List<InvestigationUnderCategoryItem>? catalog,
  ]) =>
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
    List<InvestigationUnderCategoryItem>? catalog,
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
}
