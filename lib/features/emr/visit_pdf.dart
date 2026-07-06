import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/emr.dart';

/// Generates and prints/shares a visit summary PDF (client-side, no API).
class VisitPdf {
  VisitPdf._();

  static Future<pw.Document> build(PetVisit visit) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Visit Record — ${visit.visitNumber}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Date: ${visit.visitDate}${visit.visitTime != null ? ' ${visit.visitTime}' : ''}'),
          pw.Text('Type: ${visit.visitType} · Status: ${visit.status}'),
          pw.Text('Patient: ${visit.pet?.name ?? 'Pet #${visit.petId}'}'),
          if (visit.doctor != null) pw.Text('Doctor: ${visit.doctor!.name}'),
          pw.Divider(),
          if (visit.chiefComplaint != null && visit.chiefComplaint!.isNotEmpty) ...[
            _heading('Chief Complaint'),
            pw.Text(visit.chiefComplaint!),
            pw.SizedBox(height: 12),
          ],
          if (_hasVitals(visit)) ...[
            _heading('Vitals'),
            pw.Text(_vitalsLine(visit)),
            pw.SizedBox(height: 12),
          ],
          if (visit.diagnoses != null && visit.diagnoses!.isNotEmpty) ...[
            _heading('Diagnoses'),
            pw.Text(visit.diagnoses!.map((d) => d.diagnosisName).join(', ')),
            pw.SizedBox(height: 12),
          ],
          if (visit.treatments != null && visit.treatments!.isNotEmpty) ...[
            _heading('Treatments'),
            ...visit.treatments!.map(
              (t) => pw.Text('• ${t.treatmentName} × ${t.quantity} @ ₹${t.unitPrice}'),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.medicines != null && visit.medicines!.isNotEmpty) ...[
            _heading('Prescriptions'),
            ...visit.medicines!.map(
              (m) => pw.Text(
                '• ${m.medicineName}'
                '${m.dosage != null ? ' — ${m.dosage}' : ''}'
                '${m.frequency != null ? ', ${m.frequency}' : ''}'
                ' × ${m.quantity}',
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (visit.clinicalNotes != null && visit.clinicalNotes!.isNotEmpty) ...[
            _heading('Clinical Notes'),
            pw.Text(visit.clinicalNotes!),
            pw.SizedBox(height: 12),
          ],
          if (visit.followUpDate != null) ...[
            _heading('Follow-up'),
            pw.Text([
              visit.followUpDate!,
              if (visit.followUpNotes != null) visit.followUpNotes!,
            ].join('\n')),
          ],
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  static bool _hasVitals(PetVisit v) =>
      v.temperature != null ||
      v.weight != null ||
      v.heartRate != null ||
      v.respiratoryRate != null;

  static String _vitalsLine(PetVisit v) {
    final parts = <String>[];
    if (v.temperature != null) parts.add('Temp: ${v.temperature} °F');
    if (v.weight != null) parts.add('Weight: ${v.weight} kg');
    if (v.heartRate != null) parts.add('HR: ${v.heartRate} bpm');
    if (v.respiratoryRate != null) parts.add('RR: ${v.respiratoryRate}');
    return parts.join(' · ');
  }

  static Future<void> printVisit(PetVisit visit) async {
    final doc = await build(visit);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
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
