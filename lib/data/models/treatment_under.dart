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

  static bool isValid(String? value) => value != null && keys.contains(value);

  static String? normalize(String? value) => isValid(value) ? value : null;

  /// Old visit lines without a snapshot fall back to Unique so they stay visible.
  static String forVisit({String? snapshot, String? fromProduct}) =>
      normalize(snapshot) ?? normalize(fromProduct) ?? unique;

  static String labelOf(String? value) =>
      labels[normalize(value) ?? unique] ?? 'Unique';

  static List<MapEntry<String, List<T>>> groupBy<T>(
    Iterable<T> items,
    String? Function(T) categoryOf,
  ) {
    return [
      for (final key in keys)
        MapEntry(
          key,
          items
              .where((item) => forVisit(snapshot: categoryOf(item)) == key)
              .toList(),
        ),
    ].where((e) => e.value.isNotEmpty).toList();
  }
}
