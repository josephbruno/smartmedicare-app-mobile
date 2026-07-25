import 'dart:typed_data';

bool get isSupported => false;

Future<List<String>> listPrinters() async => const [];

Future<bool> printRaw({
  required String printerName,
  required Uint8List data,
}) async =>
    false;
