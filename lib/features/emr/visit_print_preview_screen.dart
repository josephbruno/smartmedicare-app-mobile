import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'visit_pdf.dart';

/// Full-screen visit PDF preview with Print / Share actions.
class VisitPrintPreviewScreen extends StatelessWidget {
  const VisitPrintPreviewScreen({
    super.key,
    required this.visit,
    this.clinic,
  });

  final PetVisit visit;
  final VisitClinicInfo? clinic;

  static Future<void> open(
    BuildContext context, {
    required PetVisit visit,
    VisitClinicInfo? clinic,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VisitPrintPreviewScreen(visit: visit, clinic: clinic),
      ),
    );
  }

  Future<VisitClinicInfo> _resolveClinic(BuildContext context) async {
    // Always refresh from current branch so preview never shows stale shop name.
    final auth = context.read<AuthSession>();
    final branches = context.read<AppServices>().branches;
    return VisitPdf.resolveClinic(auth: auth, branches: branches);
  }

  @override
  Widget build(BuildContext context) {
    final pageFormat = PdfPageFormat.a5.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview · ${visit.visitNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: PdfPreview(
        build: (format) async {
          final resolved = await _resolveClinic(context);
          final doc = await VisitPdf.build(visit, clinic: resolved);
          return doc.save();
        },
        initialPageFormat: pageFormat,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'visit-${visit.visitNumber}.pdf',
        maxPageWidth: 900,
        scrollViewDecoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
        pdfPreviewPageDecoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: Colors.white,
          iconColor: AppTheme.primary,
          textStyle: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
