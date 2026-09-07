import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/pos_desktop_settings_section.dart';
import 'widgets/visit_summary_printer_settings_section.dart';

/// Local USB thermal printer setup (XPrinter TSPL or Retsol RTP 80 ESC/POS).
class UsbPrinterSettingsScreen extends StatelessWidget {
  const UsbPrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Printers',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'USB thermal is for POS bills (TSPL or ESC/POS). Visit summary is a separate A5 PDF printer on this computer. '
          'Pick each queue once — checkout and visit print then go out with no dialog.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        const PosDesktopSettingsSection(printerFocused: true),
        const VisitSummaryPrinterSettingsSection(),
      ],
    );
  }
}
