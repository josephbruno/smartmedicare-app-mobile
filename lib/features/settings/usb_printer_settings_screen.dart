import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/pos_desktop_settings_section.dart';

/// Local USB TSPL thermal printer setup (XPrinter, 203 dpi) for cashier desktops.
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
          'Configure the local XPrinter TSPL USB printer (203 dpi) on this computer. '
          'Print sends the bill directly to the selected printer — no dialog.',
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
