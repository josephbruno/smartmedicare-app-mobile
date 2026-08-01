import 'dart:typed_data';

import 'windows_print_bridge_stub.dart'
    if (dart.library.io) 'windows_print_bridge_io.dart' as impl;

/// Platform bridge for listing printers and sending raw TSPL bytes.
/// On Windows/Linux, local USB thermal printers (XPrinter TSPL) are used.
abstract final class WindowsPrintBridge {
  static bool get isSupported => impl.isSupported;

  static Future<List<String>> listPrinters() => impl.listPrinters();

  static Future<bool> printRaw({
    required String printerName,
    required Uint8List data,
  }) =>
      impl.printRaw(printerName: printerName, data: data);
}
