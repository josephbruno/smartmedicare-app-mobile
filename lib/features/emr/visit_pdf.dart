import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/desktop/desktop_prefs.dart';
import '../../core/services/receipt_branch_store.dart';
import '../../core/services/windows_print_bridge.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/emr.dart';
import '../../data/models/shop.dart';
import '../../data/services/settings_service.dart';

/// Clinic header info for visit print/download (A5).
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

  static VisitClinicInfo? _cachedClinic;
  static int? _cachedBranchId;
  static DateTime? _cachedAt;
  static const _clinicTtl = Duration(minutes: 5);

  static const _primary = PdfColor.fromInt(0xFF1D4ED8);
  static const _text = PdfColor.fromInt(0xFF0F172A);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _surface = PdfColor.fromInt(0xFFF8FAFC);

  static pw.Font? _fontRegular;
  static pw.Font? _fontSemi;
  static pw.Font? _fontBold;

  /// ISO A5: portrait 148 × 210 mm, landscape 210 × 148 mm.
  static PdfPageFormat pageFormatFor(SummaryPageOrientation orientation) {
    const short = 148 * PdfPageFormat.mm;
    const long = 210 * PdfPageFormat.mm;
    return orientation == SummaryPageOrientation.landscape
        ? PdfPageFormat(long, short)
        : PdfPageFormat(short, long);
  }

  static Future<PdfPageFormat> resolvePageFormat() async {
    return pageFormatFor(await DesktopPrefs.getSummaryPageOrientation());
  }

  /// Page margins (points). Kept tight for A5.
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

  static Future<void> _ensureFonts() async {
    if (_fontRegular != null) return;
    try {
      _fontRegular = await PdfGoogleFonts.notoSansRegular();
      _fontSemi = await PdfGoogleFonts.notoSansSemiBold();
      _fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      // Offline: Helvetica regular/bold. Semibold falls back to regular.
    }
  }

  static pw.TextStyle _headingStyle([double size = _fsSection]) {
    return pw.TextStyle(
      font: _fontBold,
      fontSize: size,
      fontWeight: _fontBold == null ? pw.FontWeight.bold : null,
      color: _text,
    );
  }

  static pw.TextStyle _semiStyle([double size = _fsBody]) {
    return pw.TextStyle(
      font: _fontSemi,
      fontSize: size,
      fontWeight: _fontSemi == null ? pw.FontWeight.normal : null,
      color: _text,
      lineSpacing: 1.25,
    );
  }

  static pw.TextStyle _regularStyle([double size = _fsBody]) {
    return pw.TextStyle(
      font: _fontRegular,
      fontSize: size,
      fontWeight: _fontRegular == null ? pw.FontWeight.normal : null,
      color: _text,
      lineSpacing: 1.25,
    );
  }

  static Future<pw.Document> build(
    PetVisit visit, {
    VisitClinicInfo? clinic,
    PdfPageFormat? format,
  }) async {
    return buildAll([visit], clinic: clinic, format: format);
  }

  /// One A5 page per visit (orientation from printer settings).
  static Future<pw.Document> buildAll(
    List<PetVisit> visits, {
    VisitClinicInfo? clinic,
    PdfPageFormat? format,
  }) async {
    await _ensureFonts();
    final page = format ?? await resolvePageFormat();
    final doc = pw.Document();
    final clinicName = clinic?.name.trim().isNotEmpty == true
        ? clinic!.name.trim()
        : 'Clinic';
    final clinicAddress = clinic?.address.trim() ?? '';
    final clinicPhone = clinic?.phone?.trim();

    for (final visit in visits) {
      final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
      final time = _formatTime(visit.visitTime);

      doc.addPage(
        pw.Page(
          pageFormat: page,
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
                              _bodyText(_join(_visitVitals(visit))),
                            ],
                            _divider(),
                            _sectionTitle('Investigation'),
                            _investigationBody(visit),
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: _panel(child: _clinicalNotesBody(visit)),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    flex: 2,
                    child: _panel(child: _followUpBody(visit)),
                  ),
                ],
              ),
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
              font: _fontBold,
              fontSize: _fsClinic,
              fontWeight: _fontBold == null ? pw.FontWeight.bold : null,
              color: _primary,
            ),
          ),
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: _regularStyle(_fsSubtitle),
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
          style: _regularStyle(_fsLabel),
        ),
        pw.Text(
          _t(value),
          style: _semiStyle(_fsBody),
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
        style: _headingStyle(_fsSection),
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

  static pw.Widget _clinicalNotesBody(PetVisit visit) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Clinical notes'),
        pw.Container(
          alignment: pw.Alignment.topLeft,
          constraints: const pw.BoxConstraints(
            minHeight: _fsBody * 1.35 * 2,
          ),
          child: _bodyText(
            visit.displayClinicalNotes.isNotEmpty
                ? _t(visit.displayClinicalNotes)
                : _empty,
          ),
        ),
      ],
    );
  }

  static pw.Widget _followUpBody(PetVisit visit) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Adv to Review on'),
        if (visit.followUpDate != null) ...[
          _bodyText(_t(visit.followUpDate), semi: true),
          if (visit.followUpNotes != null &&
              visit.followUpNotes!.trim().isNotEmpty)
            _bodyText(_t(visit.followUpNotes)),
        ] else
          _bodyText(_empty),
      ],
    );
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
            style: _semiStyle(_fsBody),
          ),
          if (items[i].notes.trim().isNotEmpty)
            pw.Text(
              _t(items[i].notes),
              style: _regularStyle(_fsMeta),
            ),
        ],
      ],
    );
  }

  static pw.Widget _medicinesBody(PetVisit visit) {
    return _medicineRows(VisitMedicine.prescriptionsOf(visit.medicines));
  }

  static pw.Widget _medicineRows(List<VisitMedicine> meds) {
    if (meds.isEmpty) return _bodyText(_empty);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < meds.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _t(meds[i].medicineName),
                      style: _semiStyle(_fsBody),
                    ),
                    if (_medicineMeta(meds[i]).isNotEmpty)
                      pw.Text(
                        _medicineMeta(meds[i]),
                        style: _regularStyle(_fsMeta),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                'x ${meds[i].quantity}',
                style: _regularStyle(_fsMeta),
              ),
            ],
          ),
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
    final kitLines = VisitSummaryTreatmentLine.fromTreatments(
      visit.treatments ?? const <VisitTreatment>[],
    );
    final clinicMeds = VisitMedicine.clinicTreatments(visit.medicines);
    if (kitLines.isEmpty && clinicMeds.isEmpty) return _bodyText(_empty);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kitLines.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _t(kitLines[i].name),
                      style: _semiStyle(_fsBody),
                    ),
                    if (!kitLines[i].fromKit &&
                        kitLines[i].notes != null &&
                        kitLines[i].notes!.trim().isNotEmpty)
                      pw.Text(
                        _t(kitLines[i].notes),
                        style: _regularStyle(_fsMeta),
                      ),
                  ],
                ),
              ),
              if (!kitLines[i].fromKit && kitLines[i].quantity != null) ...[
                pw.SizedBox(width: 4),
                pw.Text(
                  'x ${kitLines[i].quantity}',
                  style: _regularStyle(_fsMeta),
                ),
              ],
            ],
          ),
        ],
        if (kitLines.isNotEmpty && clinicMeds.isNotEmpty) pw.SizedBox(height: 4),
        if (clinicMeds.isNotEmpty) _medicineRows(clinicMeds),
      ],
    );
  }

  static pw.Widget _bodyText(
    String text, {
    bool semi = false,
  }) {
    return pw.Text(
      _t(text),
      style: semi ? _semiStyle(_fsBody) : _regularStyle(_fsBody),
    );
  }

  static String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
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

    if (_cachedClinic != null &&
        _cachedBranchId == branchId &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _clinicTtl) {
      return _cachedClinic!;
    }

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

    final info = VisitClinicInfo(name: name, address: address, phone: phone);
    _cachedClinic = info;
    _cachedBranchId = branchId;
    _cachedAt = DateTime.now();
    return info;
  }

  static Future<VisitPrintResult> printVisit(
    PetVisit visit, {
    VisitClinicInfo? clinic,
  }) {
    return printVisits(
      [visit],
      clinic: clinic,
      name: 'Visit ${visit.visitNumber}',
    );
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

  static Future<VisitPrintResult> printVisits(
    List<PetVisit> visits, {
    VisitClinicInfo? clinic,
    String? name,
  }) async {
    if (visits.isEmpty) return VisitPrintResult.failed;
    final page = await resolvePageFormat();
    final doc = await buildAll(visits, clinic: clinic, format: page);
    final label = name ??
        (visits.length == 1
            ? 'Visit ${visits.first.visitNumber}'
            : 'Visit summary (${visits.length})');
    return _sendPdf(
      bytes: await doc.save(),
      name: label,
      format: page,
    );
  }

  /// Sample A5 page to verify the saved summary printer and orientation.
  static Future<VisitPrintResult> printSample({
    required bool dialog,
    VisitClinicInfo? clinic,
  }) async {
    final page = await resolvePageFormat();
    final doc = await build(sampleVisit(), clinic: clinic, format: page);
    return _sendPdf(
      bytes: await doc.save(),
      name: 'Visit summary test',
      format: page,
      forceDialog: dialog,
      requireSavedPrinter: !dialog,
    );
  }

  static Future<List<String>> listPrinterNames() async {
    final names = <String>{};
    try {
      for (final printer in await Printing.listPrinters()) {
        final name = printer.name.trim();
        if (name.isNotEmpty) names.add(name);
      }
    } catch (_) {}
    if (names.isEmpty && WindowsPrintBridge.isSupported) {
      try {
        names.addAll(await WindowsPrintBridge.listPrinters());
      } catch (_) {}
    }
    final list = names.toList()..sort();
    return list;
  }

  static PetVisit sampleVisit() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return PetVisit(
      id: 0,
      petId: 0,
      customerId: 0,
      visitNumber: 'VS-TEST',
      visitType: 'consultation',
      visitDate: date,
      visitTime: time,
      chiefComplaint:
          'TEST PRINT — Visit summary sample. Check A5 paper, orientation, margins, and layout.',
      temperature: 39.2,
      weight: 12,
      heartRate: 90,
      respiratoryRate: 24,
      clinicalNotes:
          'Sample clinical notes. If this page looks correct, real visit summaries will print the same.',
      investigation: 'CBC | Sample\nX-Ray chest',
      followUpDate: date,
      followUpNotes: 'Recheck in 5 days',
      status: 'completed',
      pet: PetSearchResult(
        id: 0,
        customerId: 0,
        name: 'Sample Pet',
        species: 'Canine',
        breed: 'Indie',
        customerName: 'Test Owner',
        customerPhone: '0000000000',
      ),
      doctor: DoctorLite(id: 0, name: 'Test'),
      treatments: [
        VisitTreatment(
          treatmentName: 'Wound dressing',
          quantity: 1,
          notes: 'Sample',
        ),
      ],
      medicines: [
        VisitMedicine(
          medicineName: 'Amoxicillin 250mg',
          frequency: 'BID',
          durationDays: 5,
          prescriptionUnderCategory: 'antibiotics',
        ),
        VisitMedicine(
          medicineName: 'Meloxicam 0.5ml',
          frequency: 'SID',
          treatmentUnderCategory: 'nsaids',
        ),
      ],
    );
  }

  static Future<VisitPrintResult> _sendPdf({
    required Uint8List bytes,
    required String name,
    PdfPageFormat? format,
    bool forceDialog = false,
    bool requireSavedPrinter = false,
  }) async {
    final page = format ?? await resolvePageFormat();
    final direct = !forceDialog && await DesktopPrefs.getDirectSummaryPrint();
    if (direct) {
      final saved = (await DesktopPrefs.getSummaryPrinterName()).trim();
      if (saved.isEmpty) {
        if (requireSavedPrinter) return VisitPrintResult.noPrinterConfigured;
      } else {
        final printer = await _resolvePrinter(requireSaved: true);
        if (printer == null) {
          if (requireSavedPrinter) return VisitPrintResult.noPrinterConfigured;
        } else {
          try {
            final info = await Printing.info();
            if (info.directPrint) {
              final ok = await Printing.directPrintPdf(
                printer: printer,
                onLayout: (_) async => bytes,
                format: page,
                name: name,
                usePrinterSettings: false,
                dynamicLayout: false,
              );
              if (ok) return VisitPrintResult.directSuccess;
              if (requireSavedPrinter) return VisitPrintResult.failed;
            } else if (requireSavedPrinter) {
              return VisitPrintResult.unsupported;
            }
          } catch (_) {
            if (requireSavedPrinter) return VisitPrintResult.failed;
          }
        }
      }
    }

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        format: page,
        name: name,
        usePrinterSettings: false,
        dynamicLayout: false,
      );
      return VisitPrintResult.dialogOpened;
    } catch (_) {
      return VisitPrintResult.failed;
    }
  }

  static Future<Printer?> _resolvePrinter({bool requireSaved = false}) async {
    final saved = (await DesktopPrefs.getSummaryPrinterName()).trim();
    if (requireSaved && saved.isEmpty) return null;

    List<Printer> printers = const [];
    try {
      printers = await Printing.listPrinters();
    } catch (_) {}

    if (saved.isNotEmpty) {
      for (final printer in printers) {
        if (printer.name == saved || printer.url == saved) return printer;
      }
      return Printer(url: saved, name: saved);
    }

    for (final printer in printers) {
      if (printer.isDefault && printer.isAvailable) return printer;
    }
    for (final printer in printers) {
      if (printer.isAvailable) return printer;
    }
    return null;
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

enum VisitPrintResult {
  directSuccess,
  dialogOpened,
  failed,
  unsupported,
  noPrinterConfigured,
}

extension VisitPrintResultMessage on VisitPrintResult {
  String get userMessage {
    switch (this) {
      case VisitPrintResult.directSuccess:
        return 'Visit summary sent to printer';
      case VisitPrintResult.dialogOpened:
        return 'Print dialog opened';
      case VisitPrintResult.failed:
          return 'Print failed — check A5 paper and the portrait/landscape setting';
      case VisitPrintResult.unsupported:
        return 'Direct summary print is available on this computer\'s desktop app only';
      case VisitPrintResult.noPrinterConfigured:
        return 'Select a visit summary printer in Printers settings first';
    }
  }

  bool get isSuccess =>
      this == VisitPrintResult.directSuccess ||
      this == VisitPrintResult.dialogOpened;
}
