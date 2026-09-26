/// Port of [frontend/src/utils/gst.ts]
class GstSummaryLine {
  GstSummaryLine({
    required this.hsn,
    required this.taxableValue,
    required this.gstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  final String hsn;
  final double taxableValue;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;

  double get totalGst => cgst + sgst + igst;
}

class GstSlabBreakdown {
  GstSlabBreakdown({
    required this.rate,
    required this.taxableValue,
    required this.totalGst,
  });

  final double rate;
  final double taxableValue;
  final double totalGst;
}

class GstUtils {
  static const gstRates = [0, 5, 12, 18, 28];

  /// Round to paise, half away from zero — matches PHP round($x, 2) on the backend.
  /// `(x * 100).round() / 100` is wrong for 4.975 (stored as 4.97499…); the tiny
  /// bias absorbs that binary error without affecting real 2-decimal amounts.
  static double roundMoney(double value) {
    if (!value.isFinite) return 0;
    final sign = value < 0 ? -1 : 1;
    return sign * ((value.abs() * 100) + 1e-7).round() / 100;
  }

  /// Bill-level discount applied BEFORE tax (same rule as the backend's
  /// InvoiceService::calculateTotals): split by taxable value, last line takes the
  /// rounding remainder, GST re-computed on each line's reduced taxable value.
  static List<({double taxable, double cgst, double sgst})> taxLinesAfterDiscount(
    List<({double taxable, double cgstRate, double sgstRate, double cgst, double sgst})> lines,
    double discountAmount,
  ) {
    final subtotal = roundMoney(lines.fold(0.0, (s, l) => s + l.taxable));
    if (discountAmount <= 0 || subtotal <= 0) {
      return [for (final l in lines) (taxable: l.taxable, cgst: l.cgst, sgst: l.sgst)];
    }
    var remaining = roundMoney(discountAmount);
    final out = <({double taxable, double cgst, double sgst})>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      var share = i == lines.length - 1
          ? remaining
          : roundMoney(discountAmount * l.taxable / subtotal);
      if (share > l.taxable) share = l.taxable;
      remaining = roundMoney(remaining - share);
      final taxable = roundMoney(l.taxable - share);
      out.add((
        taxable: taxable,
        cgst: roundMoney(taxable * l.cgstRate / 100),
        sgst: roundMoney(taxable * l.sgstRate / 100),
      ));
    }
    return out;
  }

  static double calculateGST(double taxableAmount, double gstRate) {
    return roundMoney(taxableAmount * gstRate / 100);
  }

  static ({double cgst, double sgst}) splitGST(double taxableAmount, double gstRate) {
    final half = roundMoney(taxableAmount * (gstRate / 2) / 100);
    return (cgst: half, sgst: half);
  }

  static double getTaxableFromInclusive(double price, double gstRate) {
    return roundMoney(price / (1 + gstRate / 100));
  }

  static String formatCurrency(double amount, {String symbol = '₹'}) {
    return symbol + amount.toStringAsFixed(2);
  }

  static List<GstSummaryLine> generateGSTSummary(List<GstItemInput> items) {
    final map = <String, GstSummaryLine>{};

    for (final item in items) {
      final key = '${item.hsnCode ?? 'NA'}-${item.gstRate}';
      final existing = map[key];
      if (existing != null) {
        map[key] = GstSummaryLine(
          hsn: existing.hsn,
          taxableValue: existing.taxableValue + item.taxableAmount,
          gstRate: existing.gstRate,
          cgst: existing.cgst + item.cgstAmount,
          sgst: existing.sgst + item.sgstAmount,
          igst: existing.igst + item.igstAmount,
        );
      } else {
        map[key] = GstSummaryLine(
          hsn: item.hsnCode ?? 'N/A',
          taxableValue: item.taxableAmount,
          gstRate: item.gstRate,
          cgst: item.cgstAmount,
          sgst: item.sgstAmount,
          igst: item.igstAmount,
        );
      }
    }

    return map.values.toList()
      ..sort((a, b) => a.gstRate.compareTo(b.gstRate));
  }

  static List<GstSlabBreakdown> slabBreakdown(List<GstSummaryLine> lines) {
    final slabs = <double, GstSlabBreakdown>{};
    for (final row in lines) {
      final existing = slabs[row.gstRate];
      if (existing != null) {
        slabs[row.gstRate] = GstSlabBreakdown(
          rate: row.gstRate,
          taxableValue: existing.taxableValue + row.taxableValue,
          totalGst: existing.totalGst + row.totalGst,
        );
      } else {
        slabs[row.gstRate] = GstSlabBreakdown(
          rate: row.gstRate,
          taxableValue: row.taxableValue,
          totalGst: row.totalGst,
        );
      }
    }
    return slabs.values.toList()..sort((a, b) => a.rate.compareTo(b.rate));
  }
}

class GstItemInput {
  GstItemInput({
    this.hsnCode,
    required this.taxableAmount,
    required this.gstRate,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
  });

  final String? hsnCode;
  final double taxableAmount;
  final double gstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
}
