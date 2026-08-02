// Direct TSPL sample print using the Flutter TSPL builder + WinSpool RAW.
//
// Run from maran-billing-flutter-app:
//   dart run tool/direct_tspl_print.dart
//
// Optional args:
//   dart run tool/direct_tspl_print.dart "Maran Clinic" "XP-470B TSPL Raw"

import 'dart:io';
import 'dart:typed_data';

import 'package:maran/core/services/tspl_logo_bitmap.dart';
import 'package:maran/core/services/tspl_receipt_builder.dart';
import 'package:maran/core/services/windows_raw_spooler.dart';

Future<void> main(List<String> args) async {
  if (!Platform.isWindows) {
    stderr.writeln('This tool targets Windows WinSpool RAW (XP-470B).');
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
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('tspl') && lower.contains('raw')) {
        printer = name;
        break;
      }
    }
  }
  if (printer.isEmpty) {
    for (final name in printers) {
      final lower = name.toLowerCase();
      if (lower.contains('xp-470') || lower.contains('xprinter')) {
        printer = name;
        break;
      }
    }
  }
  if (printer.isEmpty) {
    stderr.writeln('No XPrinter found. Pass the printer name as arg 2.');
    exitCode = 3;
    return;
  }

  final raw = await TsplReceiptBuilder.buildSampleBytes(
    shopName: shopName,
    shopPhone: '9488350208',
    shopAddress: 'Vimaladevi Complex, Kanji Road, Vengikkal, Tiruvannamalai.',
    billerName: 'user1',
    includeLogo: TsplLogoBitmap.pngBytes != null,
  );

  final preview = String.fromCharCodes(
    raw.where((b) => (b >= 32 && b < 127) || b == 10 || b == 13),
  );
  stdout.writeln('--- TSPL (text) ---');
  final cut = preview.indexOf('BITMAP');
  stdout.writeln(cut > 0 ? preview.substring(0, cut) : preview);
  stdout.writeln(
    'payloadBytes=${raw.length} logo=${TsplLogoBitmap.pngBytes != null}',
  );
  stdout.writeln('---');
  stdout.writeln('Sending RAW TSPL to "$printer" …');

  final ok = await WindowsRawSpooler.printRaw(
    printerName: printer,
    data: Uint8List.fromList(raw),
  );

  if (ok) {
    stdout.writeln('OK — light font + logo TSPL print succeeded.');
    exitCode = 0;
  } else {
    stderr.writeln('FAILED — RAW print returned false.');
    exitCode = 1;
  }
}
