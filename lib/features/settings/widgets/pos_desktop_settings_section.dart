import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/desktop/desktop_prefs.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/services/receipt_branch_store.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/services/windows_print_bridge.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dropdown.dart';

/// POS / desktop toggles stored in SharedPreferences.
///
/// [printerFocused] highlights USB thermal printer setup for cashier desktops.
class PosDesktopSettingsSection extends StatefulWidget {
  const PosDesktopSettingsSection({super.key, this.printerFocused = false});

  final bool printerFocused;

  @override
  State<PosDesktopSettingsSection> createState() => _PosDesktopSettingsSectionState();
}

class _PosDesktopSettingsSectionState extends State<PosDesktopSettingsSection> {
  bool _autoPrint = false;
  bool _sound = true;
  bool _directPrint = true;
  PrintLanguage _language = PrintLanguage.tspl;
  String _printerName = '';
  String _tsplPrinter = '';
  String _escposPrinter = '';
  int _paperWidth = 70;
  List<String> _printers = [];
  bool _loading = true;
  bool _loadingPrinters = false;
  bool _testing = false;

  bool get _isEscPos => _language == PrintLanguage.escpos;

  bool get _isDesktopPrintSupported {
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
    final language = await DesktopPrefs.getPrintLanguage();
    final tsplPrinter = await DesktopPrefs.getThermalPrinterName();
    final escposPrinter = await DesktopPrefs.getEscPosPrinterName();
    final paper = await DesktopPrefs.getThermalPaperWidthMm();
    if (!mounted) return;
    setState(() {
      _autoPrint = auto;
      _sound = sound;
      _directPrint = direct;
      _language = language;
      _tsplPrinter = tsplPrinter;
      _escposPrinter = escposPrinter;
      _printerName =
          language == PrintLanguage.escpos ? escposPrinter : tsplPrinter;
      _paperWidth = paper;
      _loading = false;
    });
    if (_isDesktopPrintSupported) {
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
      }
    });
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    final auth = context.read<AuthSession>();
    final services = context.read<AppServices>();
    await ReceiptBranchStore.sync(branches: services.branches, auth: auth);
    final header = await ReceiptBranchStore.resolveForPrint(auth);
    final sample = await ThermalPrinterService.printSampleBill(
      shopName: header.name.isEmpty
          ? 'Maran Veterinary Hospital'
          : header.name,
      companyName: header.shopName,
      shopPhone: header.phone,
      shopGstin: header.gstin,
      shopAddress: header.address,
      billerName: auth.user?.name,
    );
    if (!mounted) return;
    setState(() => _testing = false);
    await _showPrintPreviewDialog(sample);
  }

  void _showRootSnack(String message, {Color? backgroundColor}) {
    // Never use ScaffoldMessenger.of(dialog/settings context) after async gaps —
    // the element may already be deactivated (print takes several seconds).
    final messenger = AppMessenger.rootKey.currentState;
    if (messenger == null) return;
    final rootCtx = AppMessenger.rootKey.currentContext;
    final bar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
    );
    if (rootCtx != null && rootCtx.mounted) {
      AppMessenger.show(rootCtx, bar);
    } else {
      messenger.showSnackBar(bar);
    }
  }

  Future<void> _setLanguage(PrintLanguage language) async {
    await DesktopPrefs.setPrintLanguage(language);
    if (!mounted) return;
    setState(() {
      _language = language;
      _printerName =
          language == PrintLanguage.escpos ? _escposPrinter : _tsplPrinter;
      _paperWidth = language == PrintLanguage.escpos ? 80 : 70;
    });
  }

  Future<void> _setPrinterName(String name) async {
    if (_language == PrintLanguage.escpos) {
      await DesktopPrefs.setEscPosPrinterName(name);
    } else {
      await DesktopPrefs.setThermalPrinterName(name);
    }
    await DesktopPrefs.setDirectThermalPrint(true);
    if (!mounted) return;
    setState(() {
      _printerName = name;
      _directPrint = true;
      if (_language == PrintLanguage.escpos) {
        _escposPrinter = name;
      } else {
        _tsplPrinter = name;
      }
    });
  }

  String _printerHelperText() {
    if (_printers.isEmpty) {
      return _isEscPos
          ? 'No printers found — plug in the Retsol RTP 80, install Generic / Text Only, then refresh'
          : 'No printers found — plug in the USB XPrinter, then refresh';
    }
    if (_printerName.isEmpty) {
      return _isEscPos
          ? 'Select Generic / Text Only (RAW ESC/POS) for the RTP 80'
          : 'TSPL · 203 dpi';
    }
    final lower = _printerName.toLowerCase();
    if (_isEscPos) {
      if (lower.contains('generic') ||
          lower.contains('retsol') ||
          lower.contains('rtp') ||
          lower.contains('text')) {
        return 'RAW ESC/POS → $_printerName (recommended)';
      }
      return 'Prefer "Generic / Text Only" — GDI drivers often queue without printing';
    }
    if (lower.contains('tspl')) {
      return 'RAW TSPL → $_printerName (recommended)';
    }
    return 'Prefer "XP-470B TSPL Raw" — Seagull driver often queues without printing';
  }

  Future<void> _showPrintPreviewDialog(ThermalSamplePrintResult sample) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        var status = sample.result;
        var printing = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final statusColor = status.isSuccess ? AppTheme.accent : Colors.red;
            return AlertDialog(
              title: Text(
                sample.language == PrintLanguage.escpos
                    ? 'ESC/POS receipt preview'
                    : 'TSPL command preview',
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      status.userMessage,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '203 dpi · $_paperWidth mm · $_printerName',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              sample.commands.trimRight(),
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontFamilyFallback: ['Courier New', 'monospace'],
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: printing
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: sample.commands),
                          );
                          _showRootSnack(
                            sample.language == PrintLanguage.escpos
                                ? 'Receipt preview copied'
                                : 'TSPL commands copied',
                          );
                        },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy'),
                ),
                OutlinedButton.icon(
                  onPressed: printing || _printerName.isEmpty
                      ? null
                      : () async {
                          setDialogState(() => printing = true);
                          final result = sample.rawBytes != null
                              ? await ThermalPrinterService.printRawBytes(
                                  sample.rawBytes!,
                                )
                              : sample.language == PrintLanguage.escpos
                                  ? ThermalPrintResult.failed
                                  : await ThermalPrinterService.printTsplCommands(
                                      sample.commands,
                                    );
                          if (ctx.mounted) {
                            setDialogState(() {
                              status = result;
                              printing = false;
                            });
                          }
                          _showRootSnack(
                            result.userMessage,
                            backgroundColor:
                                result.isSuccess ? Colors.green : Colors.red,
                          );
                        },
                  icon: printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: Text(printing ? 'Printing…' : 'Direct Print'),
                ),
                FilledButton(
                  onPressed: printing ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
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

    final printerOnly = widget.printerFocused;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              printerOnly ? Icons.print_outlined : Icons.desktop_windows_outlined,
              color: AppTheme.primary,
            ),
            title: Text(
              printerOnly ? 'USB Thermal Printer' : 'Desktop & POS',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              printerOnly
                  ? (_isEscPos
                      ? 'Local Retsol RTP 80 · ESC/POS · 80 mm — configured on this PC'
                      : 'Local XPrinter · TSPL · 203 dpi — configured on this PC')
                  : 'Receipt printing and notifications',
            ),
          ),
          if (!printerOnly) ...[
            SwitchListTile(
              title: const Text('Auto-print receipt after checkout'),
              subtitle: Text(
                _directPrint && _isDesktopPrintSupported
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
          ],
          if (_isDesktopPrintSupported) ...[
            if (!printerOnly) const Divider(height: 1),
            if (!printerOnly)
              ListTile(
                leading: const Icon(Icons.print_outlined, color: AppTheme.primary),
                title: const Text('USB thermal printer', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _isEscPos
                      ? 'Retsol RTP 80 ESC/POS (80 mm) installed on this computer'
                      : 'XPrinter TSPL (203 dpi) installed on this computer',
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<PrintLanguage>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(
                    value: PrintLanguage.tspl,
                    label: Text('TSPL · XPrinter'),
                    tooltip: 'Branch 1 — XP-470B TSPL',
                  ),
                  ButtonSegment(
                    value: PrintLanguage.escpos,
                    label: Text('ESC/POS · RTP 80'),
                    tooltip: 'Branch 2 — 80 mm receipt printer',
                  ),
                ],
                selected: {_language},
                onSelectionChanged: (selected) {
                  if (selected.isEmpty) return;
                  _setLanguage(selected.first);
                },
              ),
            ),
            if (_isEscPos)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Install the Retsol RTP 80 in Windows as Generic / Text Only (RAW). '
                  'GDI drivers accept the job then never print.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                ),
              ),
            SwitchListTile(
              title: const Text('Direct USB print (no dialog)'),
              subtitle: Text(
                _isEscPos
                    ? 'ESC/POS commands to the selected Retsol RTP 80'
                    : 'TSPL commands (203 dpi) to the selected local XPrinter',
              ),
              value: _directPrint,
              onChanged: (v) async {
                await DesktopPrefs.setDirectThermalPrint(v);
                setState(() => _directPrint = v);
              },
            ),
            if (printerOnly)
              SwitchListTile(
                title: const Text('Auto-print receipt after checkout'),
                subtitle: const Text('Prints immediately to the configured USB printer'),
                value: _autoPrint,
                onChanged: (v) async {
                  await DesktopPrefs.setAutoPrintReceipt(v);
                  setState(() => _autoPrint = v);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppDropdownButtonFormField<String>(
                      value: _dropdownPrinterValue(),
                      items: _printerDropdownItems(),
                      hint: Text(
                        _isEscPos
                            ? 'Select Generic / Text Only queue'
                            : 'Select TSPL Raw queue',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Local USB printer',
                        border: const OutlineInputBorder(),
                        helperText: _printerHelperText(),
                        helperMaxLines: 2,
                        helperStyle: TextStyle(
                          color: _printerName.isNotEmpty && _printers.isNotEmpty
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontWeight: _printerName.isNotEmpty && _printers.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                      onChanged: (v) async {
                        if (v == null) return;
                        await _setPrinterName(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    // Align with the field body (below floating label).
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      tooltip: 'Refresh local printers',
                      onPressed: _loadingPrinters ? null : _refreshPrinters,
                      icon: _loadingPrinters
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paper width', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _isEscPos
                      ? '80 mm roll · ESC/POS raster · 203 dpi'
                      : '70 mm · TSPL SIZE command · 203 dpi',
                ),
                trailing: Text(
                  '$_paperWidth mm',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: OutlinedButton.icon(
                onPressed: _testing || _printerName.isEmpty ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(
                  _testing
                      ? 'Printing…'
                      : (_isEscPos ? 'Test print (ESC/POS)' : 'Test print (TSPL)'),
                ),
              ),
            ),
          ] else if (printerOnly)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Direct USB print is available on Windows and Linux cashier desktops only.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
