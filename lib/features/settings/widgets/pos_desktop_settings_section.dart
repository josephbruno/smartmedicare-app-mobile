import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/desktop/desktop_prefs.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/services/windows_print_bridge.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';

/// POS / desktop toggles stored in SharedPreferences.
class PosDesktopSettingsSection extends StatefulWidget {
  const PosDesktopSettingsSection({super.key});

  @override
  State<PosDesktopSettingsSection> createState() => _PosDesktopSettingsSectionState();
}

class _PosDesktopSettingsSectionState extends State<PosDesktopSettingsSection> {
  bool _autoPrint = false;
  bool _sound = true;
  bool _directPrint = true;
  String _printerName = '';
  int _paperWidth = 80;
  List<String> _printers = [];
  bool _loading = true;
  bool _loadingPrinters = false;
  bool _testing = false;

  bool get _isWindowsDesktop {
    if (kIsWeb) return false;
    return WindowsPrintBridge.isSupported;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auto = await DesktopPrefs.getAutoPrintReceipt();
    final sound = await DesktopPrefs.getNotificationSound();
    final direct = await DesktopPrefs.getDirectThermalPrint();
    final printer = await DesktopPrefs.getThermalPrinterName();
    final paper = await DesktopPrefs.getThermalPaperWidthMm();
    if (!mounted) return;
    setState(() {
      _autoPrint = auto;
      _sound = sound;
      _directPrint = direct;
      _printerName = printer;
      _paperWidth = paper;
      _loading = false;
    });
    if (_isWindowsDesktop) {
      await _refreshPrinters();
    }
  }

  Future<void> _refreshPrinters() async {
    setState(() => _loadingPrinters = true);
    final list = await ThermalPrinterService.listWindowsPrinters();
    if (!mounted) return;
    setState(() {
      _printers = list;
      _loadingPrinters = false;
      if (_printerName.isNotEmpty && !_printers.contains(_printerName)) {
        // Keep saved name even if temporarily offline.
      } else if (_printerName.isEmpty && _printers.isNotEmpty) {
        _printerName = _printers.first;
      }
    });
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    final auth = context.read<AuthSession>();
    final result = await ThermalPrinterService.printSampleBill(
      shopName: auth.currentShop?.name ?? auth.currentBranch?.name,
    );
    if (!mounted) return;
    setState(() => _testing = false);
    AppMessenger.show(
      context,
      SnackBar(
        content: Text(result.userMessage),
        backgroundColor: result.isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  String? _dropdownPrinterValue() {
    if (_printerName.isEmpty) return null;
    final names = {
      if (_printerName.isNotEmpty) _printerName,
      ..._printers,
    };
    return names.contains(_printerName) ? _printerName : null;
  }

  List<DropdownMenuItem<String>> _printerDropdownItems() {
    final names = <String>{
      if (_printerName.isNotEmpty) _printerName,
      ..._printers,
    };
    return names
        .map(
          (p) => DropdownMenuItem(
            value: p,
            child: Text(p, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            leading: Icon(Icons.desktop_windows_outlined, color: AppTheme.primary),
            title: Text('Desktop & POS', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Receipt printing and notifications'),
          ),
          SwitchListTile(
            title: const Text('Auto-print receipt after checkout'),
            subtitle: Text(
              _directPrint && _isWindowsDesktop
                  ? 'Sends bill directly to the USB thermal printer'
                  : 'Opens print dialog when payment succeeds',
            ),
            value: _autoPrint,
            onChanged: (v) async {
              await DesktopPrefs.setAutoPrintReceipt(v);
              setState(() => _autoPrint = v);
            },
          ),
          SwitchListTile(
            title: const Text('Sound for visit billing alerts'),
            value: _sound,
            onChanged: (v) async {
              await DesktopPrefs.setNotificationSound(v);
              setState(() => _sound = v);
            },
          ),
          if (_isWindowsDesktop) ...[
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.print_outlined, color: AppTheme.primary),
              title: Text('USB thermal printer', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Epson / XPrinter installed in Windows'),
            ),
            SwitchListTile(
              title: const Text('Direct USB print (no dialog)'),
              subtitle: const Text('ESC/POS raw to the selected Windows printer'),
              value: _directPrint,
              onChanged: (v) async {
                await DesktopPrefs.setDirectThermalPrint(v);
                setState(() => _directPrint = v);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Printer',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          hint: const Text('Select USB printer'),
                          value: _dropdownPrinterValue(),
                          items: _printerDropdownItems(),
                          onChanged: (v) async {
                            if (v == null) return;
                            await DesktopPrefs.setThermalPrinterName(v);
                            setState(() => _printerName = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh printers',
                    onPressed: _loadingPrinters ? null : _refreshPrinters,
                    icon: _loadingPrinters
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (_printers.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'No printers found. Install your USB Epson/XPrinter in Windows first.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Paper width',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    isDense: true,
                    value: _paperWidth,
                    items: const [
                      DropdownMenuItem(value: 58, child: Text('58 mm')),
                      DropdownMenuItem(value: 80, child: Text('80 mm')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await DesktopPrefs.setThermalPaperWidthMm(v);
                      setState(() => _paperWidth = v);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: _testing || _printerName.isEmpty ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(_testing ? 'Printing…' : 'Test print sample bill'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
