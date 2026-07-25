import 'dart:io';
import 'dart:typed_data';

import 'package:windows_printer/windows_printer.dart';

bool get isSupported => Platform.isWindows;

Future<List<String>> listPrinters() async {
  if (!Platform.isWindows) return const [];
  try {
    return await WindowsPrinter.getAvailablePrinters();
  } catch (_) {
    return const [];
  }
}

Future<bool> printRaw({
  required String printerName,
  required Uint8List data,
}) async {
  if (!Platform.isWindows) return false;
  if (printerName.trim().isEmpty) return false;
  try {
    return await WindowsPrinter.printRawData(
      printerName: printerName,
      data: data,
      useRawDatatype: true,
    );
  } catch (_) {
    return false;
  }
}
