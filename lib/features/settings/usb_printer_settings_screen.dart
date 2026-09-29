import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/pos_desktop_settings_section.dart';
import 'widgets/visit_summary_printer_settings_section.dart';

/// Local USB thermal printer setup (XPrinter TSPL or Retsol RTP 80 ESC/POS).
class UsbPrinterSettingsScreen extends StatelessWidget {
  const UsbPrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
    return ListView(
      padding:
          EdgeInsets.fromLTRB(desktop ? 20 : 16, 16, desktop ? 20 : 16, 24),
      children: [
        Text('SETTINGS',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
        const SizedBox(height: 4),
        desktop
            ? const _PrinterHero()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Printers',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 6),
                  Text(
                    'Configure the receipt and visit-summary printers connected to this computer.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 16),
        if (desktop)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 4,
                  child: PosDesktopSettingsSection(printerFocused: true)),
              SizedBox(width: 16),
              SizedBox(width: 276, child: _PrinterPreview(receipt: true)),
            ],
          )
        else
          const PosDesktopSettingsSection(printerFocused: true),
        if (desktop)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: VisitSummaryPrinterSettingsSection()),
              SizedBox(width: 16),
              SizedBox(width: 276, child: _PrinterPreview(receipt: false)),
            ],
          )
        else
          const VisitSummaryPrinterSettingsSection(),
      ],
    );
  }
}

class _PrinterHero extends StatelessWidget {
  const _PrinterHero();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Printers',
                    style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                SizedBox(height: 4),
                Text(
                  'USB thermal is for POS bills (TSPL or ESC/POS). Visit summary uses a separate A5 PDF printer on this computer. Select each queue once for direct printing.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 300,
            height: 110,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF1F7FF), Color(0xFFE0F0FF)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -34,
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: const BoxDecoration(
                      color: Color(0x2273B5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 25,
                  child: Icon(Icons.settings_suggest_rounded,
                      size: 42, color: AppTheme.primary),
                ),
                const Positioned(
                  left: 76,
                  top: 32,
                  child: Icon(Icons.print_rounded,
                      size: 62, color: Color(0xFF233B61)),
                ),
                const Positioned(
                  right: 18,
                  bottom: 14,
                  child: Icon(Icons.receipt_long_rounded,
                      size: 48, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      );
}

class _PrinterPreview extends StatelessWidget {
  const _PrinterPreview({required this.receipt});

  final bool receipt;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        color: const Color(0xFFF1F7FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(receipt ? 'Receipt Preview' : 'Page Preview',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: receipt ? 174 : 214,
                  height: receipt ? 285 : 190,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: receipt ? const _ReceiptPaper() : const _A5Paper(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          Icon(Icons.local_hospital_rounded, color: AppTheme.primary, size: 28),
          SizedBox(height: 4),
          Text('SmartMediCare',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text('Clinic • Pets • Smarter Care',
              style: TextStyle(fontSize: 6, color: AppTheme.textSecondary)),
          Divider(height: 16),
          _PreviewLine('Invoice     #INV-00123'),
          _PreviewLine('Date     29 Sep 2026'),
          Divider(height: 15),
          _PreviewLine('Consultation       ₹350'),
          _PreviewLine('Vaccination        ₹450'),
          Divider(height: 15),
          _PreviewLine('Total              ₹800', bold: true),
          Spacer(),
          Text('Thank you!',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
        ],
      );
}

class _A5Paper extends StatelessWidget {
  const _A5Paper();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Icon(Icons.local_hospital_rounded,
                  color: AppTheme.primary, size: 24)),
          Center(
              child: Text('SmartMediCare',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
          Divider(height: 13),
          Text('Visit Summary',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          SizedBox(height: 7),
          _PreviewLine('Patient   Max (Canine)'),
          _PreviewLine('Owner     Dr. Suresh Venkat'),
          _PreviewLine('Visit Date   29 Sep 2026'),
          Divider(height: 14),
          _PreviewLine('Service          Qty   Amount', bold: true),
          _PreviewLine('Consultation       1   ₹350'),
          _PreviewLine('Vaccination        1   ₹450'),
        ],
      );
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text,
            style: TextStyle(
              fontSize: 8,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: AppTheme.textPrimary,
            )),
      );
}
