import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inrCompact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
final _pct = NumberFormat.decimalPattern('en_IN');

String formatReportCurrency(double value) => _inr.format(value);

String formatReportCurrencyCompact(double value) => _inrCompact.format(value);

String formatReportNumber(double value) => _pct.format(value);

String formatReportPercent(double value) => '${_pct.format(value)}%';

String paymentModeLabel(String mode) {
  const labels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'card': 'Card',
    'bank_transfer': 'Bank transfer',
    'cheque': 'Cheque',
    'credit': 'Credit',
    'loyalty_points': 'Loyalty',
    'other': 'Other',
  };
  return labels[mode] ?? mode.replaceAll('_', ' ');
}

String titleCaseStatus(String status) =>
    status.split('_').map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');

String productTypeLabel(String type) {
  switch (type) {
    case 'service':
      return 'Service';
    case 'medicine':
      return 'Medicine';
    case 'product':
      return 'Product';
    default:
      return titleCaseStatus(type);
  }
}

String shortDateLabel(String ymd) {
  try {
    final d = DateTime.parse(ymd);
    return DateFormat('d MMM').format(d);
  } catch (_) {
    return ymd;
  }
}

/// Date + time only (no seconds / timezone), e.g. `2026-08-08 09:40 AM`.
String formatReportDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final cleaned = raw.trim();
  final parsed = DateTime.tryParse(cleaned);
  if (parsed != null) {
    return DateFormat('yyyy-MM-dd hh:mm a').format(parsed.toLocal());
  }
  // Fall back: strip trailing offset like (+05:30) and drop seconds if present.
  var text = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  final m = RegExp(
    r'^(\d{4}-\d{2}-\d{2})\s+(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?',
    caseSensitive: false,
  ).firstMatch(text);
  if (m != null) {
    final ampm = (m.group(4) ?? '').toUpperCase();
    return ampm.isEmpty
        ? '${m.group(1)} ${m.group(2)!.padLeft(2, '0')}:${m.group(3)}'
        : '${m.group(1)} ${m.group(2)!.padLeft(2, '0')}:${m.group(3)} $ampm';
  }
  return text;
}

/// Time only, e.g. `09:40 AM`.
String formatReportTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    return DateFormat('hh:mm a').format(parsed.toLocal());
  }
  final full = formatReportDateTime(raw);
  final parts = full.split(' ');
  if (parts.length >= 3) return '${parts[parts.length - 2]} ${parts.last}';
  return full;
}
