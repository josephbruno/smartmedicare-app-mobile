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

  /// Page margins (points). Kept tight for A5 landscape.
  static const double _marginL = 10;
  static const double _marginR = 10;
  static const double _marginT = 8;
  static const double _marginB = 8;

  static Future<pw.Document> build(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) async {
    return buildAll([visit], clinic: clinic);
  }

  /// One A5 landscape page per visit (same layout as single-visit print).
  static Future<pw.Document> buildAll(
    List<PetVisit> visits, {
    VisitClinicInfo? clinic,
  }) async {
    final doc = pw.Document();
    final clinicName = clinic?.name.trim().isNotEmpty == true
        ? clinic!.name.trim()
        : 'Clinic';
    final clinicAddress = clinic?.address.trim() ?? '';
    final clinicPhone = clinic?.phone?.trim();

    for (final visit in visits) {
      final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
      final time = _formatTime(visit.visitTime);
      final typeLabel = _titleCase(visit.visitType);

      doc.addPage(
        pw.Page(
          pageFormat: _pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(_marginL, _marginT, _marginR, _marginB),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _clinicHeader(
                name: clinicName,
                address: clinicAddress,
                phone: clinicPhone,
              ),
              pw.SizedBox(height: 4),
              _ownerPetRow(
                visit: visit,
                petName: petName,
                meta: [
                  visit.visitNumber,
                  visit.visitDate,
                  if (time.isNotEmpty) time,
                  typeLabel,
                ].join(' · '),
              ),
              pw.SizedBox(height: 4),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      child: _panel(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Complaint'),
                            _bodyText(
                              visit.chiefComplaint?.trim().isNotEmpty == true
                                  ? visit.chiefComplaint!
                                  : '—',
                            ),
                            _divider(),
                            _sectionTitle('Observation'),
                            _observationBody(visit),
                            _divider(),
                            _sectionTitle('Investigation'),
                            _bodyText(
                              visit.investigation?.trim().isNotEmpty == true
                                  ? visit.investigation!
                                  : '—',
                            ),
                            _divider(),
                            _sectionTitle('Treatment'),
                            _medicinesBody(visit),
                            if (visit.followUpDate != null) ...[
                              _divider(),
                              _sectionTitle('Follow-up'),
                              _bodyText(visit.followUpDate!, bold: true),
                              if (visit.followUpNotes != null &&
                                  visit.followUpNotes!.trim().isNotEmpty)
                                _bodyText(visit.followUpNotes!, muted: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: _panel(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Procedures'),
                            _proceduresBody(visit),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),
              _pageFooter(context),
            ],
          ),
        ),
      );
    }
    return doc;
  }

  static pw.Widget _clinicHeader({
    required String name,
    required String address,
    String? phone,
  }) {
    final subtitle = [
      if (address.isNotEmpty) address,
      if (phone != null && phone.isNotEmpty) phone,
    ].join('  ·  ');

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            name,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
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
    final owner = visit.pet?.customerName?.trim().isNotEmpty == true
        ? visit.pet!.customerName!
        : '—';
    final phone = visit.pet?.customerPhone?.trim() ?? '';
    final petLine = [
      petName,
      if (species.isNotEmpty) species,
      if (visit.doctor != null) 'Dr. ${visit.doctor!.name}',
    ].join(' · ');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _kvBlock(
              'Owner',
              [owner, if (phone.isNotEmpty) phone].join(' · '),
            ),
          ),
          pw.Container(
            width: 0.6,
            margin: const pw.EdgeInsets.symmetric(horizontal: 6),
            color: _border,
          ),
          pw.Expanded(child: _kvBlock('Pet', petLine)),
          pw.Container(
            width: 0.6,
            margin: const pw.EdgeInsets.symmetric(horizontal: 6),
            color: _border,
          ),
          pw.Expanded(child: _kvBlock('Visit', meta)),
        ],
      ),
    );
  }

  static pw.Widget _kvBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _text,
          ),
        ),
      ],
    );
  }

  static pw.Widget _panel({required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: child,
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _text,
        ),
      ),
    );
  }

  static pw.Widget _divider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Container(height: 0.6, color: _border),
    );
  }

  static pw.Widget _observationBody(PetVisit visit) {
    final notes = visit.observation?.trim().isNotEmpty == true
        ? visit.observation!.trim()
        : (visit.clinicalNotes?.trim() ?? '');
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
        if (vitals.isNotEmpty) _bodyText(vitals.join(' · '), muted: true),
        for (final d in diagnoses)
          _bodyText(
            [
              if (d.isPrimary) '[P]',
              d.diagnosisName,
              if (d.icdCode != null && d.icdCode!.isNotEmpty) '(${d.icdCode})',
              '· ${_titleCase(d.severity)}',
            ].join(' '),
          ),
      ],
    );
  }

  static pw.Widget _medicinesBody(PetVisit visit) {
    final meds = visit.medicines ?? const <VisitMedicine>[];
    if (meds.isEmpty) return _bodyText('—');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < meds.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Text(
            meds[i].medicineName,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.Text(
            [
              if (meds[i].dosage != null && meds[i].dosage!.isNotEmpty)
                meds[i].dosage!,
              if (meds[i].frequency != null && meds[i].frequency!.isNotEmpty)
                meds[i].frequency!,
              if (meds[i].durationDays != null) '${meds[i].durationDays}d',
              'Qty ${meds[i].quantity}',
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
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
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      items[i].treatmentName,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    if (items[i].notes != null &&
                        items[i].notes!.trim().isNotEmpty)
                      pw.Text(
                        items[i].notes!,
                        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                '× ${items[i].quantity}',
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ],
          ),
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
        fontSize: 8.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: muted ? _muted : _text,
        lineSpacing: 1.2,
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Maran Billing',
            style: const pw.TextStyle(fontSize: 6.5, color: _muted),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 6.5, color: _muted),
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
    await printVisits([visit], clinic: clinic, name: 'Visit ${visit.visitNumber}');
  }

  static Future<void> downloadVisit(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) async {
    await downloadVisits(
      [visit],
      clinic: clinic,
      filename: 'visit-${visit.visitNumber}.pdf',
    );
  }

  static Future<void> printVisits(
    List<PetVisit> visits, {
    VisitClinicInfo? clinic,
    String? name,
  }) async {
    if (visits.isEmpty) return;
    final doc = await buildAll(visits, clinic: clinic);
    final label = name ??
        (visits.length == 1
            ? 'Visit ${visits.first.visitNumber}'
            : 'Visit summary (${visits.length})');
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      format: _pageFormat,
      name: label,
    );
  }

  static Future<void> downloadVisits(
    List<PetVisit> visits, {
    VisitClinicInfo? clinic,
    String? filename,
  }) async {
    if (visits.isEmpty) return;
    final doc = await buildAll(visits, clinic: clinic);
    final bytes = await doc.save();
    final rawName = visits.first.pet?.name.trim() ?? '';
    final petName = rawName.isNotEmpty
        ? rawName.replaceAll(RegExp(r'[^\w\-]+'), '_')
        : 'pet-${visits.first.petId}';
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename ?? 'visit-summary-$petName.pdf',
    );
  }
}
