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

  static double calculateGST(double taxableAmount, double gstRate) {
    return (taxableAmount * gstRate / 100 * 100).round() / 100;
  }

  static ({double cgst, double sgst}) splitGST(double taxableAmount, double gstRate) {
    final half = (taxableAmount * (gstRate / 2) / 100 * 100).round() / 100;
    return (cgst: half, sgst: half);
  }

  static double getTaxableFromInclusive(double price, double gstRate) {
    return ((price / (1 + gstRate / 100)) * 100).round() / 100;
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
