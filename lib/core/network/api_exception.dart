class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
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
