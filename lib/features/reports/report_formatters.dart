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

String shortDateLabel(String ymd) {
  try {
    final d = DateTime.parse(ymd);
    return DateFormat('d MMM').format(d);
  } catch (_) {
    return ymd;
  }
}
