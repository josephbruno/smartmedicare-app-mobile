import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/emr.dart';

/// Generates and prints/shares a visit summary PDF (client-side, no API).
class VisitPdf {
  VisitPdf._();

  static const _primary = PdfColor.fromInt(0xFF1D4ED8);
  static const _primarySoft = PdfColor.fromInt(0xFFEFF6FF);
  static const _accent = PdfColor.fromInt(0xFF10B981);
  static const _text = PdfColor.fromInt(0xFF0F172A);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _surface = PdfColor.fromInt(0xFFF8FAFC);
  static const _danger = PdfColor.fromInt(0xFFDC2626);
  static const _warning = PdfColor.fromInt(0xFFF59E0B);

  static Future<pw.Document> build(PetVisit visit) async {
    final doc = pw.Document();
    final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
    final time = _formatTime(visit.visitTime);
    final typeLabel = _titleCase(visit.visitType);
    final statusLabel = _statusLabel(visit.status);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (context) => _pageHeader(visit.visitNumber, context),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _heroBanner(
            petName: petName,
            visitNumber: visit.visitNumber,
            statusLabel: statusLabel,
            statusColor: _statusColor(visit.status),
            meta: [
              visit.visitDate,
              if (time.isNotEmpty) time,
              typeLabel,
            ].join('  ·  '),
            doctor: visit.doctor?.name,
            species: [
              visit.pet?.species,
              visit.pet?.breed,
            ].where((e) => e != null && e.isNotEmpty).join(' · '),
            owner: visit.pet?.customerName,
            ownerPhone: visit.pet?.customerPhone,
          ),
          pw.SizedBox(height: 18),
          if (visit.chiefComplaint != null && visit.chiefComplaint!.isNotEmpty) ...[
            _section(
              title: 'Chief complaint',
              child: pw.Text(
                visit.chiefComplaint!,
                style: const pw.TextStyle(fontSize: 11, color: _text, lineSpacing: 2),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (_hasVitals(visit)) ...[
            _section(
              title: 'Vitals',
              child: _vitalsRow(visit),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.diagnoses != null && visit.diagnoses!.isNotEmpty) ...[
            _section(
              title: 'Diagnoses',
              child: pw.Column(
                children: [
                  for (final d in visit.diagnoses!) ...[
                    _diagnosisRow(d),
                    pw.SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.treatments != null && visit.treatments!.isNotEmpty) ...[
            _section(
              title: 'Treatments',
              child: _table(
                headers: const ['Procedure', 'Qty', 'Unit price', 'Notes'],
                rows: visit.treatments!
                    .map(
                      (t) => [
                        t.treatmentName,
                        t.quantity.toString(),
                        '₹${t.unitPrice.toStringAsFixed(2)}',
                        t.notes?.isNotEmpty == true ? t.notes! : '—',
                      ],
                    )
                    .toList(),
                widths: const [3.2, 0.8, 1.2, 2.0],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.medicines != null && visit.medicines!.isNotEmpty) ...[
            _section(
              title: 'Prescriptions',
              child: _table(
                headers: const ['Medicine', 'Dosage', 'Frequency', 'Duration', 'Qty'],
                rows: visit.medicines!
                    .map(
                      (m) => [
                        m.medicineName,
                        m.dosage?.isNotEmpty == true ? m.dosage! : '—',
                        m.frequency?.isNotEmpty == true ? m.frequency! : '—',
                        m.durationDays != null ? '${m.durationDays}d' : '—',
                        m.quantity.toString(),
                      ],
                    )
                    .toList(),
                widths: const [2.6, 1.6, 1.4, 1.0, 0.7],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.serviceCharge > 0) ...[
            _section(
              title: 'Service charge',
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    visit.serviceChargeProduct?.name ?? 'Consultation / service',
                    style: const pw.TextStyle(fontSize: 10.5, color: _muted),
                  ),
                  pw.Text(
                    '₹${visit.serviceCharge.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _text,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.clinicalNotes != null && visit.clinicalNotes!.isNotEmpty) ...[
            _section(
              title: 'Clinical notes',
              child: pw.Text(
                visit.clinicalNotes!,
                style: const pw.TextStyle(fontSize: 10.5, color: _text, lineSpacing: 2.5),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.followUpDate != null)
            _section(
              title: 'Follow-up',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    visit.followUpDate!,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  if (visit.followUpNotes != null && visit.followUpNotes!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      visit.followUpNotes!,
                      style: const pw.TextStyle(fontSize: 10.5, color: _muted, lineSpacing: 2),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _pageHeader(String visitNumber, pw.Context context) {
    if (context.pageNumber == 1) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Visit Record',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
          ),
          pw.Text(
            visitNumber,
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Maran Billing',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _heroBanner({
    required String petName,
    required String visitNumber,
    required String statusLabel,
    required PdfColor statusColor,
    required String meta,
    String? doctor,
    required String species,
    String? owner,
    String? ownerPhone,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 5,
            decoration: const pw.BoxDecoration(
              color: _primary,
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(9)),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: _primarySoft,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        visitNumber,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor(
                          statusColor.red,
                          statusColor.green,
                          statusColor.blue,
                          0.12,
                        ),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Text(
                        statusLabel,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  petName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(meta, style: const pw.TextStyle(fontSize: 10, color: _muted)),
                if (species.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(species, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
                ],
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (doctor != null)
                      _metaChip('Doctor', 'Dr. $doctor'),
                    if (owner != null && owner.isNotEmpty)
                      _metaChip('Owner', owner),
                    if (ownerPhone != null && ownerPhone.isNotEmpty)
                      _metaChip('Phone', ownerPhone),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaChip(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: const pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _text),
        ),
      ],
    );
  }

  static pw.Widget _section({required String title, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6)),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _text,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  static pw.Widget _vitalsRow(PetVisit visit) {
    final items = <List<String>>[];
    if (visit.temperature != null) items.add(['Temperature', '${visit.temperature} °F']);
    if (visit.weight != null) items.add(['Weight', '${visit.weight} kg']);
    if (visit.heartRate != null) items.add(['Heart rate', '${visit.heartRate} bpm']);
    if (visit.respiratoryRate != null) {
      items.add(['Resp. rate', '${visit.respiratoryRate} /min']);
    }

    return pw.Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: _surface,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _border),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    items[i][0],
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    items[i][1],
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _diagnosisRow(VisitDiagnosis d) {
    final severityColor = switch (d.severity) {
      'severe' => _danger,
      'moderate' => _warning,
      _ => _accent,
    };

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  if (d.isPrimary) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFFEE2E2),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'Primary',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _danger,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                  ],
                  pw.Expanded(
                    child: pw.Text(
                      d.diagnosisName,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _text,
                      ),
                    ),
                  ),
                ],
              ),
              if (d.icdCode != null && d.icdCode!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  d.icdCode!,
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              ],
            ],
          ),
        ),
        pw.Text(
          _titleCase(d.severity),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: severityColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
  }) {
    final total = widths.fold<double>(0, (a, b) => a + b);
    final flex = widths.map((w) => (w / total * 1000).round()).toList();

    pw.Widget cell(String text, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: header ? 8.5 : 9.5,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? _muted : _text,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: {
        for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i].toDouble()),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _surface),
          children: [
            for (final h in headers) cell(h, header: true),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < row.length; i++)
                cell(
                  row[i],
                  align: i == 0 ? pw.TextAlign.left : pw.TextAlign.center,
                ),
            ],
          ),
      ],
    );
  }

  static bool _hasVitals(PetVisit v) =>
      v.temperature != null ||
      v.weight != null ||
      v.heartRate != null ||
      v.respiratoryRate != null;

  static String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'bill_on_hold':
        return 'On hold';
      case 'open':
        return 'Open';
      case 'completed':
        return 'Completed';
      case 'billed':
        return 'Billed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return _titleCase(status);
    }
  }

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'billed':
      case 'completed':
        return _accent;
      case 'bill_on_hold':
        return _warning;
      case 'open':
        return _primary;
      case 'cancelled':
        return _danger;
      default:
        return _muted;
    }
  }

  static Future<void> printVisit(PetVisit visit) async {
    final doc = await build(visit);
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Visit ${visit.visitNumber}',
    );
  }

  static Future<void> downloadVisit(PetVisit visit) async {
    final doc = await build(visit);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'visit-${visit.visitNumber}.pdf',
    );
  }
}
