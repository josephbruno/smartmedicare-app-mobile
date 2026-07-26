import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../desktop/desktop_prefs.dart';
import 'esc_pos_receipt_builder.dart';
import 'windows_print_bridge.dart';

/// POS receipt printing.
///
/// On Windows with a configured USB thermal printer, sends ESC/POS raw bytes
/// directly (no dialog). Otherwise falls back to the system PDF print dialog.
class ThermalPrinterService {
  static const double printerWidth = 80;
  static const double pageHeight = 300;

  /// Result of a print attempt.
  static Future<ThermalPrintResult> printReceipt({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
  }) async {
    try {
      // Prefer local USB ESC/POS (XPrinter) whenever a printer is configured.
      if (WindowsPrintBridge.isSupported) {
        final printer = await DesktopPrefs.getThermalPrinterName();
        final preferDirect = await DesktopPrefs.getDirectThermalPrint();
        if (preferDirect && printer.isNotEmpty) {
          final paper = await DesktopPrefs.getThermalPaperWidthMm();
          final bytes = await EscPosReceiptBuilder.build(
            invoice: invoice,
            items: items,
            shopName: shopName,
            shopPhone: shopPhone,
            shopGstin: shopGstin,
            shopAddress: shopAddress,
            paperWidthMm: paper,
          );
          final ok = await WindowsPrintBridge.printRaw(
            printerName: printer,
            data: Uint8List.fromList(bytes),
          );
          if (ok) {
            return ThermalPrintResult.directSuccess;
          }
          return ThermalPrintResult.failed;
        }
        if (preferDirect && printer.isEmpty) {
          return ThermalPrintResult.noPrinterConfigured;
        }
      }

      final pdf = _generateReceiptPdf(
        invoice: invoice,
        items: items,
        shopName: shopName,
        shopPhone: shopPhone,
        shopGstin: shopGstin,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice-${invoice.invoiceNumber}',
      );
      return ThermalPrintResult.dialogOpened;
    } catch (_) {
      return ThermalPrintResult.failed;
    }
  }

  static Future<ThermalPrintResult> printSampleBill({
    String? shopName,
  }) async {
    if (!WindowsPrintBridge.isSupported) {
      return ThermalPrintResult.unsupported;
    }
    final printer = await DesktopPrefs.getThermalPrinterName();
    if (printer.isEmpty) {
      return ThermalPrintResult.noPrinterConfigured;
    }
    try {
      final paper = await DesktopPrefs.getThermalPaperWidthMm();
      final bytes = await EscPosReceiptBuilder.buildSample(
        shopName: shopName ?? 'Maran Billing',
        paperWidthMm: paper,
      );
      final ok = await WindowsPrintBridge.printRaw(
        printerName: printer,
        data: Uint8List.fromList(bytes),
      );
      return ok ? ThermalPrintResult.directSuccess : ThermalPrintResult.failed;
    } catch (_) {
      return ThermalPrintResult.failed;
    }
  }

  static Future<List<String>> listWindowsPrinters() =>
      WindowsPrintBridge.listPrinters();

  static pw.Document _generateReceiptPdf({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
  }) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          printerWidth * PdfPageFormat.mm,
          pageHeight * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildHeader(shopName, shopPhone, shopGstin),
              pw.SizedBox(height: 3),
              _buildInvoiceInfo(invoice),
              pw.SizedBox(height: 3),
              if (invoice.customer != null) _buildCustomerInfo(invoice.customer!),
              pw.SizedBox(height: 3),
              _buildItemsTable(items),
              pw.SizedBox(height: 3),
              _buildTotals(invoice),
              pw.SizedBox(height: 3),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(
    String? shopName,
    String? shopPhone,
    String? shopGstin,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          shopName ?? 'Maran Billing',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (shopPhone != null)
          pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 8)),
        if (shopGstin != null)
          pw.Text('GSTIN: $shopGstin', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
      ],
    );
  }

  static pw.Widget _buildInvoiceInfo(Invoice invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Invoice #${invoice.invoiceNumber}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date: ${invoice.displayDate}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        pw.Text(
          invoice.status.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _getStatusColor(invoice.status),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Customer: ${customer.name}', style: const pw.TextStyle(fontSize: 8)),
        if ((customer.phone).isNotEmpty)
          pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<InvoiceItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              flex: 4,
              child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text('Amt', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
        ...items.map(
          (item) => pw.Row(
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 7), maxLines: 1),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                  item.quantity.toStringAsFixed(0),
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  '₹${item.totalAmount.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
      ],
    );
  }

  static pw.Widget _buildTotals(Invoice invoice) {
    final cashPayments = (invoice.payments ?? const <InvoicePayment>[])
        .where((p) => p.hasCashTenderDetail)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Subtotal', invoice.subtotal),
        if (invoice.discountAmount > 0) _buildTotalRow('Discount', -invoice.discountAmount),
        if (invoice.cgstAmount > 0) _buildTotalRow('CGST', invoice.cgstAmount),
        if (invoice.sgstAmount > 0) _buildTotalRow('SGST', invoice.sgstAmount),
        if (invoice.igstAmount > 0) _buildTotalRow('IGST', invoice.igstAmount),
        if (invoice.roundOff != 0) _buildTotalRow('Round Off', invoice.roundOff),
        pw.Divider(borderStyle: pw.BorderStyle.solid, height: 1),
        pw.Text(
          '₹${invoice.totalAmount.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        if (cashPayments.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
          for (final p in cashPayments) ...[
            _buildTotalRow('Cash received', p.tenderedAmount!),
            _buildTotalRow('Change given', p.changeReturn!),
          ],
        ],
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('₹${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
        pw.Text('Thank you!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return PdfColors.green;
      case 'draft':
        return PdfColors.orange;
      case 'partial':
        return PdfColors.amber;
      default:
        return PdfColors.black;
    }
  }
}

enum ThermalPrintResult {
  directSuccess,
  dialogOpened,
  failed,
  unsupported,
  noPrinterConfigured,
}

extension ThermalPrintResultMessage on ThermalPrintResult {
  String get userMessage {
    switch (this) {
      case ThermalPrintResult.directSuccess:
        return 'Printed to thermal printer';
      case ThermalPrintResult.dialogOpened:
        return 'Print dialog opened';
      case ThermalPrintResult.failed:
        return 'Print failed';
      case ThermalPrintResult.unsupported:
        return 'Direct USB print is available on Windows/Linux desktops only';
      case ThermalPrintResult.noPrinterConfigured:
        return 'Select a USB XPrinter in USB Printer settings first';
    }
  }

  bool get isSuccess =>
      this == ThermalPrintResult.directSuccess ||
      this == ThermalPrintResult.dialogOpened;
}
