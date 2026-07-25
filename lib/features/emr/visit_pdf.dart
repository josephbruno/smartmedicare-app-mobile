import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/emr.dart';

/// Clinic header info for visit print/download (A5 landscape).
class VisitClinicInfo {
  const VisitClinicInfo({
    required this.name,
    this.address = '',
    this.phone,
  });

  final String name;
  final String address;
  final String? phone;
}

/// Generates and prints/shares a visit summary PDF (client-side, no API).
class VisitPdf {
  VisitPdf._();

  static const _primary = PdfColor.fromInt(0xFF1D4ED8);
  static const _text = PdfColor.fromInt(0xFF0F172A);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _surface = PdfColor.fromInt(0xFFF8FAFC);

  static final PdfPageFormat _pageFormat = PdfPageFormat.a5.landscape;

  static Future<pw.Document> build(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) async {
    final doc = pw.Document();
    final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
    final time = _formatTime(visit.visitTime);
    final typeLabel = _titleCase(visit.visitType);
    final clinicName = clinic?.name.trim().isNotEmpty == true
        ? clinic!.name.trim()
        : 'Clinic';
    final clinicAddress = clinic?.address.trim() ?? '';
    final clinicPhone = clinic?.phone?.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 16),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _clinicHeader(
            name: clinicName,
            address: clinicAddress,
            phone: clinicPhone,
          ),
          pw.SizedBox(height: 8),
          _ownerPetRow(
            visit: visit,
            petName: petName,
            meta: [
              visit.visitNumber,
              visit.visitDate,
              if (time.isNotEmpty) time,
              typeLabel,
            ].join('  ·  '),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labeledBlock(
                      title: 'Complaint',
                      child: _bodyText(
                        visit.chiefComplaint?.trim().isNotEmpty == true
                            ? visit.chiefComplaint!
                            : '—',
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _labeledBlock(
                      title: 'Observation',
                      child: _observationBody(visit),
                    ),
                    pw.SizedBox(height: 8),
                    _labeledBlock(
                      title: 'Treatment',
                      child: _medicinesBody(visit),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _labeledBlock(
                  title: 'Procedures',
                  child: _proceduresBody(visit),
                ),
              ),
            ],
          ),
          if (visit.followUpDate != null) ...[
            pw.SizedBox(height: 8),
            _labeledBlock(
              title: 'Follow-up',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _bodyText(visit.followUpDate!, bold: true),
                  if (visit.followUpNotes != null &&
                      visit.followUpNotes!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    _bodyText(visit.followUpNotes!, muted: true),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _clinicHeader({
    required String name,
    required String address,
    String? phone,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            name,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          if (address.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              address,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              phone,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _ownerPetRow({
    required PetVisit visit,
    required String petName,
    required String meta,
  }) {
    final species = [
      visit.pet?.species,
      visit.pet?.breed,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Owner',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _muted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  visit.pet?.customerName?.trim().isNotEmpty == true
                      ? visit.pet!.customerName!
                      : '—',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
                if (visit.pet?.customerPhone != null &&
                    visit.pet!.customerPhone!.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    visit.pet!.customerPhone!,
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
              ],
            ),
          ),
          pw.Container(width: 1, height: 42, color: _border),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Pet',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _muted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  petName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
                if (species.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    species,
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
                if (visit.doctor != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Dr. ${visit.doctor!.name}',
                    style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                  ),
                ],
              ],
            ),
          ),
          pw.Container(width: 1, height: 42, color: _border),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Visit',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _muted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  meta,
                  style: const pw.TextStyle(fontSize: 8.5, color: _text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _labeledBlock({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6)),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _text,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  static pw.Widget _observationBody(PetVisit visit) {
    final notes = visit.clinicalNotes?.trim() ?? '';
    final vitals = <String>[];
    if (visit.temperature != null) vitals.add('Temp ${visit.temperature} °F');
    if (visit.weight != null) vitals.add('Wt ${visit.weight} kg');
    if (visit.heartRate != null) vitals.add('HR ${visit.heartRate} bpm');
    if (visit.respiratoryRate != null) {
      vitals.add('RR ${visit.respiratoryRate} /min');
    }
    final diagnoses = visit.diagnoses ?? const <VisitDiagnosis>[];

    if (notes.isEmpty && vitals.isEmpty && diagnoses.isEmpty) {
      return _bodyText('—');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (notes.isNotEmpty) _bodyText(notes),
        if (vitals.isNotEmpty) ...[
          if (notes.isNotEmpty) pw.SizedBox(height: 4),
          _bodyText(vitals.join('  ·  '), muted: true),
        ],
        if (diagnoses.isNotEmpty) ...[
          if (notes.isNotEmpty || vitals.isNotEmpty) pw.SizedBox(height: 4),
          for (final d in diagnoses) ...[
            pw.Text(
              [
                if (d.isPrimary) '[P]',
                d.diagnosisName,
                if (d.icdCode != null && d.icdCode!.isNotEmpty) '(${d.icdCode})',
                '· ${_titleCase(d.severity)}',
              ].join(' '),
              style: const pw.TextStyle(fontSize: 8.5, color: _text),
            ),
            pw.SizedBox(height: 2),
          ],
        ],
      ],
    );
  }

  static pw.Widget _medicinesBody(PetVisit visit) {
    final meds = visit.medicines ?? const <VisitMedicine>[];
    if (meds.isEmpty) return _bodyText('—');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final m in meds) ...[
          pw.Text(
            m.medicineName,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.Text(
            [
              if (m.dosage != null && m.dosage!.isNotEmpty) m.dosage!,
              if (m.frequency != null && m.frequency!.isNotEmpty) m.frequency!,
              if (m.durationDays != null) '${m.durationDays}d',
              'Qty ${m.quantity}',
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.SizedBox(height: 4),
        ],
      ],
    );
  }

  static pw.Widget _proceduresBody(PetVisit visit) {
    final items = visit.treatments ?? const <VisitTreatment>[];
    if (items.isEmpty) return _bodyText('—');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final t in items) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      t.treatmentName,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    if (t.notes != null && t.notes!.trim().isNotEmpty)
                      pw.Text(
                        t.notes!,
                        style: const pw.TextStyle(fontSize: 8, color: _muted),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '× ${t.quantity}  ·  ₹${t.unitPrice.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
      ],
    );
  }

  static pw.Widget _bodyText(
    String text, {
    bool bold = false,
    bool muted = false,
  }) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: muted ? _muted : _text,
        lineSpacing: 1.5,
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Maran Billing',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ),
    );
  }

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

  static VisitClinicInfo clinicFromAuth({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? branchName,
    String? branchAddress,
    String? branchPhone,
  }) {
    final name = (shopName != null && shopName.trim().isNotEmpty)
        ? shopName.trim()
        : (branchName?.trim().isNotEmpty == true ? branchName!.trim() : 'Clinic');
    final address = (branchAddress != null && branchAddress.trim().isNotEmpty)
        ? branchAddress.trim()
        : (shopAddress?.trim() ?? '');
    final phone = (branchPhone != null && branchPhone.trim().isNotEmpty)
        ? branchPhone.trim()
        : shopPhone;
    return VisitClinicInfo(name: name, address: address, phone: phone);
  }

  static Future<void> printVisit(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) async {
    final doc = await build(visit, clinic: clinic);
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      format: _pageFormat,
      name: 'Visit ${visit.visitNumber}',
    );
  }

  static Future<void> downloadVisit(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) async {
    final doc = await build(visit, clinic: clinic);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'visit-${visit.visitNumber}.pdf',
    );
  }
}
