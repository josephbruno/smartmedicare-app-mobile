import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import 'models/api_response.dart';

Map<String, dynamic> responseAsMap(Response<dynamic> response) {
  final d = response.data;
  if (d is Map<String, dynamic>) return d;
  if (d is Map) return Map<String, dynamic>.from(d);
  throw ApiException('Invalid response body');
}

T parseEnvelopeData<T>(
  Response<dynamic> response,
  T Function(dynamic data) parse,
) {
  final map = responseAsMap(response);
  final ok = map['success'] as bool? ?? true;
  if (!ok) {
    throw apiExceptionFromEnvelope(map);
  }
  return parse(map['data']);
}

/// Parses `{ success, data: [...], meta?: {...} }` list endpoints.
({List<T> items, PaginationMeta? meta}) parseEnvelopeList<T>(
  Response<dynamic> response,
  T Function(Map<String, dynamic>) item,
) {
  final map = responseAsMap(response);
  final ok = map['success'] as bool? ?? true;
  if (!ok) {
    throw apiExceptionFromEnvelope(map);
  }
  return (
    items: listFromData(map['data'], item),
    meta: map['meta'] is Map
        ? PaginationMeta.fromJson(Map<String, dynamic>.from(map['meta'] as Map))
        : null,
  );
}

ApiException apiExceptionFromEnvelope(Map<String, dynamic> map) {
  var msg = map['message']?.toString() ?? 'Request failed';
  Map<String, List<String>>? errors;
  final rawErrors = map['errors'];
  if (rawErrors is Map) {
    errors = {};
    rawErrors.forEach((k, v) {
      if (v is List) {
        errors![k.toString()] = v.map((e) => e.toString()).toList();
      }
    });
    for (final list in errors.values) {
      if (list.isNotEmpty) {
        final first = list.first.trim();
        if (first.isNotEmpty) {
          msg = first;
          break;
        }
      }
    }
  }
  return ApiException(msg, errors: errors);
}

List<T> listFromData<T>(dynamic data, T Function(Map<String, dynamic>) item) {
  if (data is! List) return [];
  return data
      .whereType<Map>()
      .map((e) => item(Map<String, dynamic>.from(e)))
      .toList();
}

Map<String, dynamic>? mapOrNull(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// API date fields may be `YYYY-MM-DD` or ISO-8601.
///
/// Calendar dates must stay on the local day. Laravel often serializes a
/// `date` cast under Asia/Kolkata as UTC midnight-of-that-day (e.g.
/// `2026-08-23` → `2026-08-22T18:30:00.000000Z`); reading UTC y/m/d would
/// show the previous day.
String formatApiDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final value = raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return value;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return raw;
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// API time fields may be `HH:MM` or `HH:MM:SS`.
String formatApiTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final value = raw.trim();
  if (value.length >= 5 && value[2] == ':') {
    return value.substring(0, 5);
  }
  return value;
}

double? numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
  return null;
}

int? intOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }
  return null;
}
