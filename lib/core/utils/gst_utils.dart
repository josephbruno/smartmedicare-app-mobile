/// Port of [frontend/src/utils/gst.ts]
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
}
