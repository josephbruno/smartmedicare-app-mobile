import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:windows_printer/windows_printer.dart';

import 'windows_raw_spooler.dart';

/// Direct TSPL raw print on Windows (spooler) and Linux (CUPS / USB lp).
bool get isSupported => Platform.isWindows || Platform.isLinux;

Future<List<String>> listPrinters() async {
  if (Platform.isWindows) {
    try {
      final fromPlugin = await WindowsPrinter.getAvailablePrinters();
      if (fromPlugin.isNotEmpty) return fromPlugin;
    } catch (_) {}
    return WindowsRawSpooler.listPrinters();
  }
  if (Platform.isLinux) {
    return _listLinuxPrinters();
  }
  return const [];
}

Future<bool> printRaw({
  required String printerName,
  required Uint8List data,
}) async {
  final name = printerName.trim();
  if (name.isEmpty) return false;

  if (Platform.isWindows) {
    return _printRawWindows(name, data);
  }

  if (Platform.isLinux) {
    return _printRawLinux(name, data);
  }

  return false;
}

Future<bool> _printRawWindows(String printerName, Uint8List data) async {
  // Prefer WinSpool RAW with queue verification.
  // The windows_printer plugin returns true as soon as WritePrinter succeeds,
  // which is a false positive on Seagull "Xprinter XP-470B" (jobs stick forever).
  if (await WindowsRawSpooler.printRaw(
    printerName: printerName,
    data: data,
    verifyCleared: true,
  )) {
    return true;
  }

  // Plugin fallback (no queue verify — last resort only).
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

Future<List<String>> _listLinuxPrinters() async {
  final names = <String>{};

  try {
    final result = await Process.run('lpstat', ['-a']);
    if (result.exitCode == 0) {
      for (final line in const LineSplitter().convert('${result.stdout}')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final printer = trimmed.split(RegExp(r'\s+')).first;
        if (printer.isNotEmpty) names.add(printer);
      }
    }
  } catch (_) {}

  try {
    final usbDir = Directory('/dev/usb');
    if (await usbDir.exists()) {
      await for (final entity in usbDir.list()) {
        final base = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (base.startsWith('lp')) {
          names.add(entity.path);
        }
      }
    }
  } catch (_) {}

  final list = names.toList()..sort();
  return list;
}

Future<bool> _printRawLinux(String printerName, Uint8List data) async {
  try {
    if (printerName.startsWith('/dev/')) {
      final file = File(printerName);
      if (!await file.exists()) return false;
      final raf = await file.open(mode: FileMode.writeOnly);
      try {
        await raf.writeFrom(data);
        await raf.flush();
      } finally {
        await raf.close();
      }
      return true;
    }

    final tmp = File(
      '${Directory.systemTemp.path}/maran_tspl_${DateTime.now().microsecondsSinceEpoch}.bin',
    );
    await tmp.writeAsBytes(data, flush: true);
    try {
      final result = await Process.run('lp', [
        '-d',
        printerName,
        '-o',
        'raw',
        tmp.path,
      ]);
      return result.exitCode == 0;
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  } catch (_) {
    return false;
  }
}
