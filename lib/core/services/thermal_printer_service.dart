import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../desktop/desktop_prefs.dart';
import 'escpos_receipt_builder.dart';
import 'tspl_receipt_builder.dart';
import 'windows_print_bridge.dart';

/// POS receipt printing.
///
/// On Windows/Linux with a configured USB thermal printer, sends raw bytes
/// (TSPL for XPrinter, ESC/POS for Retsol RTP 80) with no dialog. Otherwise
/// falls back to the system PDF print dialog.
class ThermalPrinterService {
  static const double printerWidth = 70;
  static const double pageHeight = 300;

  /// Result of a print attempt.
  ///
  /// When [allowSystemDialog] is false (POS checkout auto-print), only the
  /// connected USB thermal printer is used. If it is connected, print silently
  /// and continue; if not, skip printing — never open the blocking PDF dialog.
  static Future<ThermalPrintResult> printReceipt({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? companyName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    bool allowSystemDialog = true,
  }) async {
    try {
      // Prefer local USB thermal (TSPL or ESC/POS) whenever direct print is on.
      if (WindowsPrintBridge.isSupported) {
        final preferDirect = await DesktopPrefs.getDirectThermalPrint();
        final printer = preferDirect ? await _resolvePrinterName() : '';
        if (preferDirect && printer.isNotEmpty) {
          final bytes = await _buildReceiptBytes(
            invoice: invoice,
            items: items,
            shopName: shopName,
            companyName: companyName,
            shopPhone: shopPhone,
            shopGstin: shopGstin,
            shopAddress: shopAddress,
            billerName: billerName,
          );
          final ok = await WindowsPrintBridge.printRaw(
            printerName: printer,
            data: bytes,
          );
          if (ok) {
            return ThermalPrintResult.directSuccess;
          }
          // Do not fall back to a system dialog that would block checkout.
          return ThermalPrintResult.failed;
        }
        if (preferDirect && printer.isEmpty) {
          return ThermalPrintResult.noPrinterConfigured;
        }
      }

      if (!allowSystemDialog) {
        return ThermalPrintResult.noPrinterConfigured;
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

  /// Builds a sample bill (TSPL or ESC/POS) and sends it to the USB printer.
  static Future<ThermalSamplePrintResult> printSampleBill({
    String? shopName,
    String? companyName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
  }) async {
    final language = await DesktopPrefs.getPrintLanguage();
    final name = shopName ?? 'Maran Veterinary Hospital';
    if (language == PrintLanguage.escpos) {
      final sample = await EscPosReceiptBuilder.buildSample(
        shopName: _escPosShopTitle(companyName, name),
        shopPhone: shopPhone,
        shopGstin: shopGstin,
        shopAddress: shopAddress,
        billerName: billerName,
        includeLogo: true,
      );
      final result = await printRawBytes(sample.bytes);
      return ThermalSamplePrintResult(
        commands: sample.preview,
        rawBytes: sample.bytes,
        result: result,
        language: language,
      );
    }
    final rawBytes = await TsplReceiptBuilder.buildSampleBytes(
      shopName: name,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
      includeLogo: true,
    );
    final commands = await TsplReceiptBuilder.buildSampleCommands(
      shopName: name,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
    );
    final result = await printRawBytes(rawBytes);
    return ThermalSamplePrintResult(
      commands: commands,
      rawBytes: rawBytes,
      result: result,
      language: language,
    );
  }

  static Future<Uint8List> _buildReceiptBytes({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? companyName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
  }) async {
    final language = await DesktopPrefs.getPrintLanguage();
    if (language == PrintLanguage.escpos) {
      return EscPosReceiptBuilder.build(
        invoice: invoice,
        items: items,
        shopName: _escPosShopTitle(companyName, shopName),
        shopPhone: shopPhone,
        shopGstin: shopGstin,
        shopAddress: shopAddress,
        billerName: billerName,
      );
    }
    return TsplReceiptBuilder.build(
      invoice: invoice,
      items: items,
      shopName: shopName,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
    );
  }

  static String _escPosShopTitle(String? companyName, String? shopName) {
    final company = (companyName ?? '').trim();
    if (company.isNotEmpty) return company;
    final fallback = (shopName ?? '').trim();
    return fallback.isNotEmpty ? fallback : 'Maran Veterinary Hospital';
  }

  /// Sends existing TSPL command text directly to the configured USB printer.
  static Future<ThermalPrintResult> printTsplCommands(String commands) async {
    return printRawBytes(Uint8List.fromList(latin1.encode(commands)));
  }

  /// Sends raw TSPL bytes (may include BITMAP logo payload).
  static Future<ThermalPrintResult> printRawBytes(Uint8List data) async {
    if (!WindowsPrintBridge.isSupported) {
      return ThermalPrintResult.unsupported;
    }
    final printer = await _resolvePrinterName();
    if (printer.isEmpty) {
      return ThermalPrintResult.noPrinterConfigured;
    }
    try {
      final ok = await WindowsPrintBridge.printRaw(
        printerName: printer,
        data: data,
      );
      return ok ? ThermalPrintResult.directSuccess : ThermalPrintResult.failed;
    } catch (_) {
      return ThermalPrintResult.failed;
    }
  }

  static Future<List<String>> listWindowsPrinters() =>
      WindowsPrintBridge.listPrinters();

  /// Saved printer name for the active language, or auto-pick a matching queue.
  static Future<String> _resolvePrinterName() async {
    final language = await DesktopPrefs.getPrintLanguage();
    final printers = await WindowsPrintBridge.listPrinters();
    if (language == PrintLanguage.escpos) {
      return _resolveEscPosPrinterName(printers);
    }
    return _resolveTsplPrinterName(printers);
  }

  static Future<String> _resolveTsplPrinterName(List<String> printers) async {
    final preferred = _preferTsplQueue(printers);
    final saved = (await DesktopPrefs.getThermalPrinterName()).trim();
    if (saved.isNotEmpty) {
      // Migrate away from Seagull queue when a dedicated TSPL Raw queue exists.
      final savedLower = saved.toLowerCase();
      final seagullOnly = savedLower.contains('xprinter') &&
          !savedLower.contains('tspl') &&
          !savedLower.contains('generic');
      if (seagullOnly && preferred != null && preferred != saved) {
        await DesktopPrefs.setThermalPrinterName(preferred);
        return preferred;
      }
      return saved;
    }

    if (preferred == null || preferred.isEmpty) return '';
    await DesktopPrefs.setThermalPrinterName(preferred);
    await DesktopPrefs.setDirectThermalPrint(true);
    return preferred;
  }

  static Future<String> _resolveEscPosPrinterName(List<String> printers) async {
    final preferred = _preferEscPosQueue(printers);
    final saved = (await DesktopPrefs.getEscPosPrinterName()).trim();
    if (saved.isNotEmpty) return saved;

    if (preferred == null || preferred.isEmpty) return '';
    await DesktopPrefs.setEscPosPrinterName(preferred);
    await DesktopPrefs.setDirectThermalPrint(true);
    return preferred;
  }

  static String? _preferTsplQueue(List<String> printers) {
    if (printers.isEmpty) return null;
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('tspl') && lower.contains('raw')) return name;
    }
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('xp-470') && lower.contains('raw')) return name;
    }
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('generic') &&
          lower.contains('text') &&
          (lower.contains('470') || lower.contains('xprinter'))) {
        return name;
      }
    }
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('xp-470') || lower.contains('xp470')) return name;
    }
    for (final name in printers) {
      if (name.toLowerCase().contains('xprinter')) return name;
    }
    return null;
  }

  static String? _preferEscPosQueue(List<String> printers) {
    if (printers.isEmpty) return null;
    bool isTspl(String lower) =>
        lower.contains('tspl') ||
        lower.contains('xprinter') ||
        lower.contains('xp-470') ||
        lower.contains('xp470');

    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('retsol') ||
          lower.contains('rtp 80') ||
          lower.contains('rtp80') ||
          lower.contains('rtp-80')) {
        return name;
      }
    }
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (isTspl(lower)) continue;
      if (lower.contains('escpos') || lower.contains('esc/pos')) return name;
    }
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (isTspl(lower)) continue;
      if (lower.contains('generic') && lower.contains('text')) return name;
    }
    return null;
  }

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
        if (shopGstin != null && shopGstin.trim().isNotEmpty)
          pw.Text('GST No :${shopGstin.trim()}', style: const pw.TextStyle(fontSize: 8)),
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
              'Invoice #${invoice.displayInvoiceNumber}',
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
              flex: 3,
              child: pw.Text('Item', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text('MRP', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text('Rate', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text('Qty', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text('Amt', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
        ...items.map(
          (item) {
            final mrp = item.mrp > 0 ? item.mrp : item.unitPrice;
            return pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 6), maxLines: 1),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    mrp.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    item.unitPrice.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    item.quantity.toStringAsFixed(0),
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    item.totalAmount.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            );
          },
        ),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
      ],
    );
  }

  static pw.Widget _buildTotals(Invoice invoice) {
    final payments = (invoice.payments ?? const <InvoicePayment>[])
        .where((p) => p.amount > 0.009)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Subtotal', invoice.subtotal),
        if (invoice.discountAmount > 0) _buildTotalRow('Discount', -invoice.discountAmount),
        // CGST / SGST / IGST intentionally omitted from receipt print.
        if (invoice.roundOff != 0) _buildTotalRow('Round Off', invoice.roundOff),
        pw.Divider(borderStyle: pw.BorderStyle.solid, height: 1),
        pw.Text(
          '₹${invoice.totalAmount.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        if (payments.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Divider(borderStyle: pw.BorderStyle.dashed, height: 1),
          for (final p in payments) ...[
            _buildTotalRow(_paymentModeLabel(p.paymentMode), p.amount),
            if (p.hasCashTenderDetail) ...[
              _buildTotalRow('Cash received', p.tenderedAmount!),
              _buildTotalRow('Change given', p.changeReturn!),
            ],
          ],
          if (invoice.dueAmount > 0.009)
            _buildTotalRow('Balance due', invoice.dueAmount),
        ],
      ],
    );
  }

  static String _paymentModeLabel(String mode) {
    return switch (mode.toLowerCase()) {
      'cash' => 'Cash',
      'upi' => 'UPI',
      'card' => 'Card',
      'bank_transfer' => 'Bank transfer',
      'cheque' => 'Cheque',
      'loyalty_points' => 'Loyalty',
      'advance' => 'Advance',
      _ => mode.replaceAll('_', ' '),
    };
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
        pw.SizedBox(height: 2),
        pw.Text(
          'Powered by bestwaveinnovation.com',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
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

/// Sample test print payload: command preview + send result.
class ThermalSamplePrintResult {
  const ThermalSamplePrintResult({
    required this.commands,
    required this.result,
    this.rawBytes,
    this.language = PrintLanguage.tspl,
  });

  final String commands;
  final ThermalPrintResult result;
  final PrintLanguage language;

  /// Full payload including logo raster / BITMAP (for Direct Print).
  final Uint8List? rawBytes;

  bool get isSuccess => result.isSuccess;
  String get userMessage => result.userMessage;
}

extension ThermalPrintResultMessage on ThermalPrintResult {
  String get userMessage {
    switch (this) {
      case ThermalPrintResult.directSuccess:
        return 'Printed to thermal printer';
      case ThermalPrintResult.dialogOpened:
        return 'Print dialog opened';
      case ThermalPrintResult.failed:
        return 'Print failed — job stuck or printer busy. Select the RAW queue (TSPL Raw or Generic / Text Only), clear the Windows print queue, then retry';
      case ThermalPrintResult.unsupported:
        return 'Direct USB print is available on Windows/Linux desktops only';
      case ThermalPrintResult.noPrinterConfigured:
        return 'Select a USB printer in USB Printer settings first';
    }
  }

  bool get isSuccess =>
      this == ThermalPrintResult.directSuccess ||
      this == ThermalPrintResult.dialogOpened;
}
