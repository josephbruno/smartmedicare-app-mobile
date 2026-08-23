import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/services/receipt_branch_store.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/emr.dart';
import '../../data/models/shop.dart';
import '../../data/models/treatment_under.dart';
import '../../data/services/settings_service.dart';

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

  /// Shared font sizes (preview + print).
  static const double _fsClinic = 15;
  static const double _fsSubtitle = 10;
  static const double _fsLabel = 9;
  static const double _fsBody = 11;
  static const double _fsSection = 11;
  static const double _fsMeta = 9.5;
  static const double _fsFooter = 8.5;

  /// ~4 blank text lines before the clinic header (applied via top margin).
  static const double _headerTopSpace = _fsBody * 1.35 * 4;

  /// Empty-field placeholder (ASCII — Helvetica cannot draw em dash U+2014).
  static const String _empty = '-';

  /// Helvetica/WinAnsi cannot render many Unicode punctuation chars (shows as
  /// tofu boxes in print preview). Map them to plain ASCII.
  static String _t(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .replaceAll('\u2014', '-') // em dash —
        .replaceAll('\u2013', '-') // en dash –
        .replaceAll('\u2012', '-') // figure dash
        .replaceAll('\u2015', '-') // horizontal bar
        .replaceAll('\u2212', '-') // minus
        .replaceAll('\u00A0', ' ') // nbsp
        .replaceAll('\u2022', '*') // bullet
        .replaceAll('\u2026', '...') // ellipsis
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u00B7', '|') // middle dot ·
        .replaceAll('\u2022', '*');
  }

  static String _join(Iterable<String?> parts, [String sep = ' | ']) {
    return parts
        .map(_t)
        .where((e) => e.trim().isNotEmpty)
        .join(sep);
  }

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
          // Top margin includes ~4 blank lines so header never sits on the page edge.
          margin: const pw.EdgeInsets.fromLTRB(
            _marginL,
            _marginT + _headerTopSpace,
            _marginR,
            _marginB,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _clinicHeader(
                name: _t(clinicName),
                address: _t(clinicAddress),
                phone: clinicPhone == null ? null : _t(clinicPhone),
              ),
              pw.SizedBox(height: 6),
              _ownerPetRow(
                visit: visit,
                petName: _t(petName),
                meta: _join([
                  visit.visitNumber,
                  visit.visitDate,
                  if (time.isNotEmpty) time,
                  typeLabel,
                ]),
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
                                  ? _t(visit.chiefComplaint)
                                  : _empty,
                            ),
                            if (_visitVitals(visit).isNotEmpty) ...[
                              _divider(),
                              _sectionTitle('Vitals'),
                              _bodyText(_join(_visitVitals(visit)), muted: true),
                            ],
                            _divider(),
                            _sectionTitle('Investigation'),
                            _investigationBody(visit),
                            _divider(),
                            _sectionTitle('Follow-up'),
                            if (visit.followUpDate != null) ...[
                              _bodyText(_t(visit.followUpDate), bold: true),
                              if (visit.followUpNotes != null &&
                                  visit.followUpNotes!.trim().isNotEmpty)
                                _bodyText(_t(visit.followUpNotes), muted: true),
                            ] else
                              _bodyText(_empty),
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
                            _sectionTitle('Treatments'),
                            _proceduresBody(visit),
                            _divider(),
                            _sectionTitle('Prescriptions'),
                            _medicinesBody(visit),
                            if ((visit.serviceCharge) > 0) ...[
                              _divider(),
                              _sectionTitle('Consultation'),
                              _bodyText(
                                _join([
                                  visit.serviceChargeProduct?.name ??
                                      'Consultation Fee',
                                  'Rs ${visit.serviceCharge.toStringAsFixed(0)}',
                                ]),
                              ),
                            ],
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
    final subtitle = _join([
      if (address.isNotEmpty) address,
      if (phone != null && phone.isNotEmpty) phone,
    ]);

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
            _t(name),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: _fsClinic,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: _fsSubtitle, color: _muted),
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
    final species = _join([
      visit.pet?.species,
      visit.pet?.breed,
    ]);
    final owner = visit.pet?.customerName?.trim().isNotEmpty == true
        ? _t(visit.pet!.customerName)
        : _empty;
    final phone = _t(visit.pet?.customerPhone);
    final petLine = _join([
      petName,
      if (species.isNotEmpty) species,
      if (visit.doctor != null) 'Dr. ${_t(visit.doctor!.name)}',
    ]);

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
              _join([owner, if (phone.isNotEmpty) phone]),
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
            fontSize: _fsLabel,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
          ),
        ),
        pw.Text(
          _t(value),
          style: pw.TextStyle(
            fontSize: _fsBody,
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
          fontSize: _fsSection,
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

  static List<String> _visitVitals(PetVisit visit) {
    final vitals = <String>[];
    if (visit.temperature != null) {
      final f = (visit.temperature! * 9 / 5) + 32;
      vitals.add('Temp ${f.toStringAsFixed(1)} F');
    }
    if (visit.weight != null) vitals.add('Wt ${visit.weight} kg');
    if (visit.heartRate != null) vitals.add('HR ${visit.heartRate} bpm');
    if (visit.respiratoryRate != null) {
      vitals.add('RR ${visit.respiratoryRate} /min');
    }
    return vitals;
  }

  static pw.Widget _investigationBody(PetVisit visit) {
    final items = visit.investigationItems;
    if (items.isEmpty) return _bodyText(_empty);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Text(
            _t(items[i].name),
            style: pw.TextStyle(
              fontSize: _fsBody,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          if (items[i].notes.trim().isNotEmpty)
            pw.Text(
              _t(items[i].notes),
              style: const pw.TextStyle(fontSize: _fsMeta, color: _muted),
            ),
        ],
      ],
    );
  }

  static pw.Widget _medicinesBody(PetVisit visit) {
    final meds = visit.medicines ?? const <VisitMedicine>[];
    if (meds.isEmpty) return _bodyText(_empty);

    final groups = TreatmentUnderCategory.groupBy(
      meds,
      (m) => m.treatmentUnderCategory ?? m.product?.treatmentUnderCategory,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          if (g > 0) pw.SizedBox(height: 4),
          pw.Text(
            TreatmentUnderCategory.labelOf(groups[g].key),
            style: pw.TextStyle(
              fontSize: _fsMeta,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 2),
          for (var i = 0; i < groups[g].value.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 2),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _t(groups[g].value[i].medicineName),
                        style: pw.TextStyle(
                          fontSize: _fsBody,
                          fontWeight: pw.FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      if (_medicineMeta(groups[g].value[i]).isNotEmpty)
                        pw.Text(
                          _medicineMeta(groups[g].value[i]),
                          style: const pw.TextStyle(fontSize: _fsMeta, color: _muted),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Text(
                  'x ${groups[g].value[i].quantity}',
                  style: const pw.TextStyle(fontSize: _fsMeta, color: _muted),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  static String _medicineMeta(VisitMedicine med) {
    return _join([
      if (med.frequency != null && med.frequency!.isNotEmpty) med.frequency!,
      if (med.durationDays != null) '${med.durationDays}d',
    ]);
  }

  static pw.Widget _proceduresBody(PetVisit visit) {
    final items = visit.treatments ?? const <VisitTreatment>[];
    if (items.isEmpty) return _bodyText(_empty);

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
                      _t(items[i].treatmentName),
                      style: pw.TextStyle(
                        fontSize: _fsBody,
                        fontWeight: pw.FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    if (items[i].notes != null &&
                        items[i].notes!.trim().isNotEmpty)
                      pw.Text(
                        _t(items[i].notes),
                        style: const pw.TextStyle(fontSize: _fsMeta, color: _muted),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                'x ${items[i].quantity}',
                style: const pw.TextStyle(fontSize: _fsMeta, color: _muted),
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
      _t(text),
      style: pw.TextStyle(
        fontSize: _fsBody,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: muted ? _muted : _text,
        lineSpacing: 1.25,
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
            'Powered by bestwaveinnovation.com',
            style: const pw.TextStyle(fontSize: _fsFooter, color: _muted),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: _fsFooter, color: _muted),
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
    // Header title: current branch name first, then shop.
    final name = (branchName != null && branchName.trim().isNotEmpty)
        ? branchName.trim()
        : (shopName?.trim().isNotEmpty == true ? shopName!.trim() : 'Clinic');
    // Address / phone: prefer current branch details, then shop.
    final address = (branchAddress != null && branchAddress.trim().isNotEmpty)
        ? branchAddress.trim()
        : (shopAddress?.trim() ?? '');
    final phone = (branchPhone != null && branchPhone.trim().isNotEmpty)
        ? branchPhone.trim()
        : shopPhone;
    return VisitClinicInfo(name: name, address: address, phone: phone);
  }

  /// Resolve clinic header from the logged-in branch (API + session fallback).
  /// Always prefers branch name/address/phone — never the shop name when a
  /// branch is available (shop is "Maran Clinic", branch is e.g. "Maran Veterinary Hospital").
  static Future<VisitClinicInfo> resolveClinic({
    required AuthSession auth,
    BranchService? branches,
  }) async {
    final shop = auth.currentShop;
    final branchLite = auth.currentBranch;
    final branchId = auth.currentBranchId ?? branchLite?.id;

    // 1) Fresh branch from API (authoritative).
    Branch? apiBranch;
    if (branches != null && branchId != null && branchId > 0) {
      try {
        final list = await branches.list();
        for (final b in list) {
          if (b.id == branchId) {
            apiBranch = b;
            break;
          }
        }
      } catch (_) {
        // Cashiers may lack branch.list — fall back to session branch.
      }
    }

    final branchName = (apiBranch?.name.trim().isNotEmpty == true)
        ? apiBranch!.name.trim()
        : (branchLite?.name.trim().isNotEmpty == true
            ? branchLite!.name.trim()
            : '');

    final branchAddress = apiBranch != null
        ? [
            apiBranch.address,
            apiBranch.city,
            apiBranch.state,
            apiBranch.pincode,
          ]
            .whereType<String>()
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(', ')
        : (branchLite?.formattedAddress.trim() ?? '');

    final branchPhone = (apiBranch?.phone?.trim().isNotEmpty == true)
        ? apiBranch!.phone!.trim()
        : (branchLite?.phone?.trim().isNotEmpty == true
            ? branchLite!.phone!.trim()
            : '');

    // 2) Title MUST be branch name when known — do not use shop name.
    final name = branchName.isNotEmpty
        ? branchName
        : (shop?.name.trim().isNotEmpty == true ? shop!.name.trim() : 'Clinic');

    final address = branchAddress.isNotEmpty
        ? branchAddress
        : (shop?.formattedAddress.trim() ?? '');

    final phone = branchPhone.isNotEmpty
        ? branchPhone
        : shop?.phone?.trim();

    // Keep thermal receipt cache in sync with the same branch header.
    if (branchId != null && branchId > 0 && name.isNotEmpty) {
      await ReceiptBranchStore.save(
        ReceiptBranchInfo(
          branchId: branchId,
          name: name,
          address: address,
          phone: phone,
        ),
      );
    }

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
