class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors, this.code});

  final String message;
  final int? statusCode;

  /// Machine-readable reason from the API, e.g. PLAN_UPGRADE_REQUIRED, PLAN_LIMIT_REACHED.
  final String? code;

  bool get isPlanError =>
      code == 'PLAN_UPGRADE_REQUIRED' || code == 'PLAN_LIMIT_REACHED';
  final Map<String, List<String>>? errors;

  /// Prefers the first field-level validation error when present.
  String get displayMessage {
    final fieldErrors = errors;
    if (fieldErrors != null && fieldErrors.isNotEmpty) {
      for (final list in fieldErrors.values) {
        if (list.isNotEmpty) {
          final first = list.first.trim();
          if (first.isNotEmpty) return first;
        }
      }
    }
    return message;
  }

  @override
  String toString() => displayMessage;
}
