import 'dart:typed_data';

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
class VisitPrintPreviewScreen extends StatefulWidget {
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

  @override
  State<VisitPrintPreviewScreen> createState() =>
      _VisitPrintPreviewScreenState();
}

class _VisitPrintPreviewScreenState extends State<VisitPrintPreviewScreen> {
  late final Future<Uint8List> _pdfBytes;

  @override
  void initState() {
    super.initState();
    _pdfBytes = _buildOnce();
  }

  Future<Uint8List> _buildOnce() async {
    final services = context.read<AppServices>();
    final auth = context.read<AuthSession>();
    final clinic = widget.clinic ??
        await VisitPdf.resolveClinic(
          auth: auth,
          branches: services.branches,
        );
    final doc = await VisitPdf.build(widget.visit, clinic: clinic);
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final pageFormat = PdfPageFormat.a5.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview · ${widget.visit.visitNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfBytes,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not build visit preview.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snap.data!;
          return PdfPreview(
            key: ValueKey('visit-pdf-${widget.visit.id}'),
            build: (_) async => bytes,
            initialPageFormat: pageFormat,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            shouldRepaint: false,
            pdfFileName: 'visit-${widget.visit.visitNumber}.pdf',
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
          );
        },
      ),
    );
  }
}
