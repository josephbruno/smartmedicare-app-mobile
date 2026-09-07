import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/desktop/desktop_prefs.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../emr/visit_pdf.dart';

/// Local A5 visit-summary printer, stored on this PC like POS thermal print.
class VisitSummaryPrinterSettingsSection extends StatefulWidget {
  const VisitSummaryPrinterSettingsSection({super.key});

  @override
  State<VisitSummaryPrinterSettingsSection> createState() =>
      _VisitSummaryPrinterSettingsSectionState();
}

class _VisitSummaryPrinterSettingsSectionState
    extends State<VisitSummaryPrinterSettingsSection> {
  bool _directPrint = true;
  bool _autoPrint = false;
  String _printerName = '';
  SummaryPageOrientation _orientation = SummaryPageOrientation.portrait;
  List<String> _printers = [];
  bool _loading = true;
  bool _loadingPrinters = false;
  bool _testingDirect = false;
  bool _testingDialog = false;
  bool _directSupported = false;

  bool get _desktop => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final direct = await DesktopPrefs.getDirectSummaryPrint();
    final auto = await DesktopPrefs.getAutoPrintSummary();
    final printer = await DesktopPrefs.getSummaryPrinterName();
    final orientation = await DesktopPrefs.getSummaryPageOrientation();
    var supported = false;
    try {
      final info = await Printing.info();
      supported = info.directPrint;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _directPrint = direct;
      _autoPrint = auto;
      _printerName = printer;
      _orientation = orientation;
      _directSupported = supported;
      _loading = false;
    });
    if (_desktop) {
      await _refreshPrinters();
    }
  }

  Future<void> _refreshPrinters() async {
    setState(() => _loadingPrinters = true);
    final list = await VisitPdf.listPrinterNames();
    if (!mounted) return;
    setState(() {
      _printers = list;
      _loadingPrinters = false;
    });
  }

  Future<VisitClinicInfo> _clinicInfo() {
    final auth = context.read<AuthSession>();
    final services = context.read<AppServices>();
    return VisitPdf.resolveClinic(
      auth: auth,
      branches: services.branches,
    );
  }

  void _showRootSnack(String message, {Color? backgroundColor}) {
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

  Future<void> _setOrientation(SummaryPageOrientation value) async {
    await DesktopPrefs.setSummaryPageOrientation(value);
    if (!mounted) return;
    setState(() => _orientation = value);
  }

  String _orientationSizeLabel(SummaryPageOrientation orientation) {
    return orientation == SummaryPageOrientation.landscape
        ? '210 × 148 mm'
        : '148 × 210 mm';
  }

  String _orientationHelperText() {
    return _orientation == SummaryPageOrientation.landscape
        ? 'A5 landscape — 210 mm wide × 148 mm tall'
        : 'A5 portrait — 148 mm wide × 210 mm tall';
  }

  Future<void> _setPrinterName(String name) async {
    await DesktopPrefs.setSummaryPrinterName(name);
    await DesktopPrefs.setDirectSummaryPrint(true);
    if (!mounted) return;
    setState(() {
      _printerName = name;
      _directPrint = true;
    });
  }

  Future<void> _testPrint({required bool dialog}) async {
    if (dialog) {
      setState(() => _testingDialog = true);
    } else {
      setState(() => _testingDirect = true);
    }
    try {
      final clinic = await _clinicInfo();
      final result = await VisitPdf.printSample(
        dialog: dialog,
        clinic: clinic,
      );
      _showRootSnack(
        result.userMessage,
        backgroundColor: result.isSuccess ? Colors.green : Colors.red,
      );
    } catch (e) {
      _showRootSnack('$e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _testingDirect = false;
          _testingDialog = false;
        });
      }
    }
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

  bool get _looksThermal {
    final lower = _printerName.toLowerCase();
    return lower.contains('tspl') ||
        lower.contains('generic') ||
        lower.contains('text only') ||
        lower.contains('xprinter') ||
        lower.contains('rtp') ||
        lower.contains('retsol');
  }

  String _printerHelperText() {
    if (_printers.isEmpty) {
      return 'No printers found — install an A5 laser/inkjet, then refresh';
    }
    if (_printerName.isEmpty) {
      return 'A5 laser / inkjet — not the TSPL or Generic / Text Only thermal queue';
    }
    if (_looksThermal) {
      return 'This looks like a thermal RAW queue — visit summaries will not print correctly';
    }
    return 'A5 ${_orientation.name} · ${_orientationSizeLabel(_orientation)} → $_printerName';
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
            leading: Icon(Icons.description_outlined, color: AppTheme.primary),
            title: Text(
              'Visit Summary Printer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'A5 PDF on this computer — choose portrait or landscape below',
            ),
          ),
          if (_desktop) ...[
            SwitchListTile(
              title: const Text('Direct summary print (no dialog)'),
              subtitle: Text(
                _directSupported
                    ? 'Sends A5 ${_orientation.name} (${_orientationSizeLabel(_orientation)}) with no dialog'
                    : 'This device cannot skip the print dialog',
              ),
              value: _directPrint && _directSupported,
              onChanged: !_directSupported
                  ? null
                  : (v) async {
                      await DesktopPrefs.setDirectSummaryPrint(v);
                      setState(() => _directPrint = v);
                    },
            ),
            SwitchListTile(
              title: const Text('Auto-print summary after complete visit'),
              subtitle: const Text(
                'Prints immediately when a visit is marked complete',
              ),
              value: _autoPrint,
              onChanged: (v) async {
                await DesktopPrefs.setAutoPrintSummary(v);
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
                      hint: const Text('Select A5 laser / inkjet queue'),
                      decoration: InputDecoration(
                        labelText: 'Local summary printer',
                        border: const OutlineInputBorder(),
                        helperText: _printerHelperText(),
                        helperMaxLines: 2,
                        helperStyle: TextStyle(
                          color: _looksThermal
                              ? AppTheme.danger
                              : (_printerName.isNotEmpty && _printers.isNotEmpty
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary),
                          fontWeight: _printerName.isNotEmpty &&
                                  _printers.isNotEmpty &&
                                  !_looksThermal
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppDropdownButtonFormField<SummaryPageOrientation>(
                value: _orientation,
                items: [
                  DropdownMenuItem(
                    value: SummaryPageOrientation.portrait,
                    child: Text(
                      'Portrait · ${_orientationSizeLabel(SummaryPageOrientation.portrait)}',
                    ),
                  ),
                  DropdownMenuItem(
                    value: SummaryPageOrientation.landscape,
                    child: Text(
                      'Landscape · ${_orientationSizeLabel(SummaryPageOrientation.landscape)}',
                    ),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'A5 orientation',
                  border: const OutlineInputBorder(),
                  helperText: _orientationHelperText(),
                  helperMaxLines: 2,
                  helperStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
                onChanged: (v) async {
                  if (v == null) return;
                  await _setOrientation(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _testingDirect || _printerName.isEmpty
                        ? null
                        : () => _testPrint(dialog: false),
                    icon: _testingDirect
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(
                      _testingDirect
                          ? 'Printing…'
                          : 'Test print (direct)',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _testingDialog
                        ? null
                        : () => _testPrint(dialog: true),
                    icon: _testingDialog
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_disabled_outlined, size: 18),
                    label: Text(
                      _testingDialog
                          ? 'Printing…'
                          : 'Test print (dialog)',
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Direct visit-summary print is available on Windows, macOS, and Linux desktops. '
                'On this device, Print still opens the system dialog.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
