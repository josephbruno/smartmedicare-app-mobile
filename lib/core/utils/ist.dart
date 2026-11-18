import 'package:intl/intl.dart';

/// All dates/times are shown in IST (UTC+05:30), whatever the device or
/// server time zone (servers run UTC). Mirrors `frontend/src/utils/datetime.ts`.
const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Converts any instant to IST wall-clock time (returned as a UTC-flagged
/// [DateTime] whose fields read as IST — never call `toLocal()` on it).
DateTime toIst(DateTime t) => t.toUtc().add(_istOffset);

/// Current time in IST.
DateTime nowIst() => toIst(DateTime.now());

/// Today's date in IST as `yyyy-MM-dd`.
String todayIst() => DateFormat('yyyy-MM-dd').format(nowIst());

/// Parses an API timestamp. A bare `yyyy-MM-dd` is a calendar date already
/// in IST and is returned as-is (not shifted).
DateTime? parseApiInstant(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    final d = DateTime.tryParse(s);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }
  final p = DateTime.tryParse(s);
  if (p == null) return null;
  return toIst(p);
}

/// `14 Oct 2026` in IST. Empty string when [raw] is null/invalid.
String formatDateIst(String? raw, {String pattern = 'dd MMM yyyy'}) {
  final d = parseApiInstant(raw);
  return d == null ? '' : DateFormat(pattern).format(d);
}

/// `14 Oct 2026, 03:45 PM` in IST.
String formatDateTimeIst(String? raw) =>
    formatDateIst(raw, pattern: 'dd MMM yyyy, hh:mm a');
