import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/cashier_cash_session.dart';
import 'report_formatters.dart';

class DayCloseReportPdf {
  DayCloseReportPdf._();

  static const _primary = PdfColor.fromInt(0xFF0F766E);
  static const _text = PdfColor.fromInt(0xFF0F172A);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _surface = PdfColor.fromInt(0xFFF8FAFC);

  static Future<void> print({
    required CashierDayStatus report,
    required String clinicName,
    String? branchName,
  }) async {
    final doc = await build(
      report: report,
      clinicName: clinicName,
      branchName: branchName,
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static Future<void> share({
    required CashierDayStatus report,
    required String clinicName,
    String? branchName,
  }) async {
    final doc = await build(
      report: report,
      clinicName: clinicName,
      branchName: branchName,
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'day-close-${report.businessDate}.pdf',
    );
  }

  static Future<pw.Document> build({
    required CashierDayStatus report,
    required String clinicName,
    String? branchName,
  }) async {
    final doc = pw.Document();
    final t = report.totals;
    final closedBy = report.dayClose?.closedByName;
    final closedAt = report.dayClose?.closedAt;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            clinicName,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Day Close Summary Report',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _text),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            [
              'Date: ${report.businessDate}',
              if (branchName != null && branchName.isNotEmpty) 'Branch: $branchName',
              report.isClosed ? 'Status: CLOSED' : 'Status: OPEN / IN PROGRESS',
              if (closedBy != null) 'Closed by: $closedBy',
              if (closedAt != null) 'Closed at: $closedAt',
            ].join('  ·  '),
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Branch totals'),
          pw.SizedBox(height: 6),
          _totalsGrid(t),
          pw.SizedBox(height: 16),
          _sectionTitle('Cashier shifts (${report.sessionsCount})'),
          pw.SizedBox(height: 6),
          _sessionsTable(report.sessions),
          if (report.movements.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Drawer movements'),
            pw.SizedBox(height: 6),
            _movementsTable(report.movements),
          ],
          if (report.dayClose?.notes != null && report.dayClose!.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Notes'),
            pw.SizedBox(height: 4),
            pw.Text(report.dayClose!.notes!, style: const pw.TextStyle(fontSize: 10, color: _text)),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated ${DateTime.now().toIso8601String()}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _text),
      ),
    );
  }

  static pw.Widget _totalsGrid(CashierDayTotals t) {
    final cells = [
      ('Opening', t.openingAmount),
      ('Cash collected', t.cashCollected),
      ('Cash in', t.cashInTotal),
      ('Cash out (taken)', t.cashOutTotal),
      ('Expected closing', t.expectedClosingAmount),
      ('Counted', t.countedAmount),
      ('Variance', t.variance),
      ('Open in-hand', t.amountInHandOpen),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cells
          .map(
            (c) => pw.Container(
              width: 120,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(c.$1, style: const pw.TextStyle(fontSize: 8, color: _muted)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    formatReportCurrency(c.$2),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _text),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _sessionsTable(List<CashierCashSession> sessions) {
    if (sessions.isEmpty) {
      return pw.Text('No cashier shifts for this date.', style: const pw.TextStyle(fontSize: 10, color: _muted));
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _text),
      cellStyle: const pw.TextStyle(fontSize: 8, color: _text),
      headerDecoration: const pw.BoxDecoration(color: _surface),
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headers: const [
        'Cashier',
        'Status',
        'Opening',
        'Collected',
        'Taken',
        'Expected',
        'Counted',
        'Variance',
      ],
      data: sessions
          .map(
            (s) => [
              s.userName ?? 'User #${s.userId}',
              s.isOpen ? 'OPEN' : 'CLOSED',
              formatReportCurrency(s.openingAmount),
              formatReportCurrency(s.cashCollected),
              formatReportCurrency(s.cashOutTotal),
              formatReportCurrency(s.expectedClosingAmount),
              s.countedAmount == null ? '—' : formatReportCurrency(s.countedAmount!),
              s.variance == null ? '—' : formatReportCurrency(s.variance!),
            ],
          )
          .toList(),
    );
  }

  static pw.Widget _movementsTable(List<CashierCashMovement> movements) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _text),
      cellStyle: const pw.TextStyle(fontSize: 8, color: _text),
      headerDecoration: const pw.BoxDecoration(color: _surface),
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headers: const ['Time', 'User', 'Type', 'Amount', 'Notes'],
      data: movements
          .map(
            (m) => [
              m.createdAt ?? '—',
              m.userName ?? 'User #${m.userId}',
              m.type,
              formatReportCurrency(m.amount),
              (m.notes ?? '').trim().isEmpty ? '—' : m.notes!,
            ],
          )
          .toList(),
    );
  }
}
