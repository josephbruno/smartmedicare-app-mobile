import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/pos_desktop_settings_section.dart';

/// Local USB thermal printer setup (XPrinter TSPL or Retsol RTP 80 ESC/POS).
class UsbPrinterSettingsScreen extends StatelessWidget {
  const UsbPrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'USB Thermal Printer',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the print language for this computer, then pick the Windows queue. '
          'Branch 1 uses XPrinter TSPL. Branch 2 uses Retsol RTP 80 ESC/POS. '
          'Checkout prints the same bill to whichever language is selected — no dialog.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        const PosDesktopSettingsSection(printerFocused: true),
      ],
    );
  }
}
