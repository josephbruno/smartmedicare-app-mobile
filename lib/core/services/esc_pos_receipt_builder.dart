import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../data/models/invoice.dart';

/// Builds ESC/POS bytes for an 58/80mm thermal bill.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static Future<List<int>> build({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    int paperWidthMm = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);

    var bytes = <int>[];
    bytes += g.reset();

    final name = (shopName ?? 'Maran Billing').trim();
    bytes += g.text(
      name,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (shopAddress != null && shopAddress.trim().isNotEmpty) {
      bytes += g.text(
        shopAddress.trim(),
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (shopPhone != null && shopPhone.trim().isNotEmpty) {
      bytes += g.text(
        shopPhone.trim(),
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    // GSTIN intentionally omitted from thermal print.
    bytes += g.hr();

    bytes += g.text(
      'Inv: ${invoice.invoiceNumber}',
      styles: const PosStyles(bold: true),
    );
    bytes += g.text('Date: ${invoice.displayDate}');
    bytes += g.text('Status: ${invoice.status.toUpperCase()}');
    bytes += g.hr();

    final customer = invoice.customer;
    if (customer != null) {
      bytes += g.text('Customer: ${customer.name}');
      if (customer.phone.isNotEmpty) {
        bytes += g.text('Phone: ${customer.phone}');
      }
      bytes += g.hr();
    }

    bytes += g.row([
      PosColumn(
        text: 'Item',
        width: 3,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'MRP',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Rate',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: 'Amt',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    bytes += g.hr(ch: '-');

    for (final item in items) {
      final mrp = item.mrp > 0 ? item.mrp : item.unitPrice;
      final label = _clip(item.productName, paperWidthMm <= 58 ? 8 : 10);
      bytes += g.row([
        PosColumn(text: label, width: 3),
        PosColumn(
          text: _money(mrp),
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: _money(item.unitPrice),
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: item.quantity.toStringAsFixed(
            item.quantity == item.quantity.roundToDouble() ? 0 : 1,
          ),
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: item.totalAmount.toStringAsFixed(2),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += g.hr();

    bytes += _moneyRow(g, 'Subtotal', invoice.subtotal);
    if (invoice.discountAmount > 0) {
      bytes += _moneyRow(g, 'Discount', -invoice.discountAmount);
    }
    // CGST / SGST / IGST intentionally omitted from thermal print.
    if (invoice.roundOff != 0) {
      bytes += _moneyRow(g, 'Round Off', invoice.roundOff);
    }
    bytes += g.hr(ch: '=');
    bytes += g.text(
      'TOTAL  Rs ${invoice.totalAmount.toStringAsFixed(2)}',
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );

    final cashPayments = (invoice.payments ?? const <InvoicePayment>[])
        .where((p) => p.hasCashTenderDetail)
        .toList();
    if (cashPayments.isNotEmpty) {
      bytes += g.hr(ch: '-');
      for (final p in cashPayments) {
        bytes += _moneyRow(g, 'Cash received', p.tenderedAmount!);
        bytes += _moneyRow(g, 'Change given', p.changeReturn!);
      }
    }

    bytes += g.hr();
    bytes += g.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += g.text(
      'Visit again soon',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += g.feed(2);
    bytes += g.cut();

    return bytes;
  }

  /// Simple hardware / sample bill for settings Test Print.
  static Future<List<int>> buildSample({
    required String shopName,
    int paperWidthMm = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);
    var bytes = <int>[];
    bytes += g.reset();
    bytes += g.text(
      shopName.isEmpty ? 'Maran Billing' : shopName,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += g.text(
      'SAMPLE BILL',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += g.hr();
    bytes += g.row([
      PosColumn(text: 'Consult', width: 3),
      PosColumn(text: '300', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '300', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '1', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '300.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += g.row([
      PosColumn(text: 'Suture', width: 3),
      PosColumn(text: '220', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '200', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '2', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: '400.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += g.hr();
    bytes += g.text(
      'TOTAL  Rs 700.00',
      styles: const PosStyles(align: PosAlign.right, bold: true),
    );
    bytes += g.text(
      'USB thermal test OK',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  static List<int> _moneyRow(Generator g, String label, double amount) {
    return g.row([
      PosColumn(text: label, width: 7),
      PosColumn(
        text: amount.toStringAsFixed(2),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  static String _money(double amount) => amount.toStringAsFixed(2);

  static String _clip(String value, int max) {
    final t = value.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}
