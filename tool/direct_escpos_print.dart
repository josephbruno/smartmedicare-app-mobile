// Direct ESC/POS sample print using EscPosReceiptBuilder + WinSpool RAW.
//
// Run from maran-billing-flutter-app:
//   dart run tool/direct_escpos_print.dart
//
// Optional args:
//   dart run tool/direct_escpos_print.dart "Maran Clinic" "RETSOL RTP-80"

import 'dart:io';
import 'dart:typed_data';

import 'package:maran/core/services/escpos_receipt_builder.dart';
import 'package:maran/core/services/tspl_logo_bitmap.dart';
import 'package:maran/core/services/windows_raw_spooler.dart';

Future<void> main(List<String> args) async {
  if (!Platform.isWindows) {
    stderr.writeln('This tool targets Windows WinSpool RAW (Retsol RTP 80).');
    exitCode = 2;
    return;
  }

  final shopName = args.isNotEmpty ? args[0] : 'Maran Veterinary Hospital';
  final printerArg = args.length > 1 ? args[1].trim() : '';

  final logoFile = File('assets/branding/receipt-logo.png');
  if (await logoFile.exists()) {
    TsplLogoBitmap.clearCache();
    TsplLogoBitmap.pngBytes = await logoFile.readAsBytes();
  }

  final printers = await WindowsRawSpooler.listPrinters();
  stdout.writeln('Printers (${printers.length}):');
  for (final p in printers) {
    stdout.writeln('  - $p');
  }

  var printer = printerArg;
  if (printer.isEmpty) {
    printer = _preferEscPos(printers) ?? '';
  }
  if (printer.isEmpty) {
    stderr.writeln('No Retsol / ESC/POS queue found. Pass the printer name as arg 2.');
    exitCode = 3;
    return;
  }

  stdout.writeln('Selected: $printer');

  final sample = await EscPosReceiptBuilder.buildSample(
    shopName: shopName,
    shopPhone: '9488350208',
    shopAddress: 'Vimaladevi Complex, Kanji Road, Vengikkal, Tiruvannamalai.',
    billerName: 'user1',
    includeLogo: TsplLogoBitmap.pngBytes != null,
  );

  stdout.writeln('--- ESC/POS preview ---');
  stdout.writeln(sample.preview);
  stdout.writeln(
    'payloadBytes=${sample.bytes.length} logo=${TsplLogoBitmap.pngBytes != null}',
  );
  stdout.writeln('---');
  stdout.writeln('Sending RAW ESC/POS to "$printer" …');

  final ok = await WindowsRawSpooler.printRaw(
    printerName: printer,
    data: Uint8List.fromList(sample.bytes),
  );

  if (ok) {
    stdout.writeln('OK — ESC/POS sample sent to $printer.');
    exitCode = 0;
  } else {
    stderr.writeln('FAILED — RAW print returned false.');
    exitCode = 1;
  }
}

String? _preferEscPos(List<String> printers) {
  for (final name in printers) {
    final lower = name.toLowerCase();
    if (lower.contains('retsol') ||
        lower.contains('rtp-80') ||
        lower.contains('rtp 80') ||
        lower.contains('rtp80')) {
      return name;
    }
  }
  for (final name in printers) {
    final lower = name.toLowerCase();
    if (lower.contains('generic') && lower.contains('text')) return name;
  }
  return null;
}
