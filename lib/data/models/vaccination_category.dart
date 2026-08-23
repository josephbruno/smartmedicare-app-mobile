class VaccinationCategory {
  static const puppy = 'puppy';
  static const annual = 'annual';
  static const pbarv = 'pbarv';

  static const keys = [puppy, annual, pbarv];

  static const labels = {
    puppy: 'Puppy Vaccine',
    annual: 'Annual Vaccine',
    pbarv: 'PBARV',
  };

  static bool isValid(String? value) => value != null && keys.contains(value);

  static String? normalize(String? value) => isValid(value) ? value : null;

  static String inferFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('pbarv') ||
        n.contains('pep') ||
        n.contains('bite') ||
        n.contains('post-bite') ||
        n.contains('post bite')) {
      return pbarv;
    }
    if (n.contains('puppy') || n.contains('kitten') || n.contains('primary')) {
      return puppy;
    }
    return annual;
  }

  static String forVisit({String? snapshot, String? name}) =>
      normalize(snapshot) ?? inferFromName(name ?? '');

  static String labelOf(String? value) =>
      labels[normalize(value) ?? annual] ?? 'Annual Vaccine';

  static List<MapEntry<String, List<T>>> groupBy<T>(
    Iterable<T> items,
    String? Function(T) categoryOf,
  ) {
    return [
      for (final key in keys)
        MapEntry(
          key,
          items.where((item) => forVisit(snapshot: categoryOf(item)) == key).toList(),
        ),
    ].where((e) => e.value.isNotEmpty).toList();
  }
}
