import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';

/// Receipt printing via the system print dialog (desktop + mobile).
class ThermalPrinterService {
  static const double printerWidth = 80;
  static const double pageHeight = 300;

  static Future<bool> printReceipt({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
  }) async {
    try {
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
      return true;
    } catch (e) {
      return false;
    }
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
