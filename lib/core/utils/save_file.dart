import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../app_config.dart';

/// Lets the user save [bytes] as [fileName] (native "Save as" dialog on
/// desktop, system save sheet on Android/iOS). Returns the saved path, or
/// null when cancelled.
Future<String?> saveBytesAs(String fileName, Uint8List bytes) async {
  final ext = fileName.contains('.') ? fileName.split('.').last : null;
  final path = await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: ext == null ? FileType.any : FileType.custom,
    allowedExtensions: ext == null ? null : [ext],
  );
  if (path == null) return null;
  // Desktop pickers only return the chosen path; write the file ourselves.
  if (AppConfig.isDesktopPlatform) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return path;
}

/// Builds a UTF-8 CSV (with BOM so Excel opens it correctly) and saves it.
Future<String?> saveCsv(
  String fileName,
  List<String> header,
  Iterable<List<Object?>> rows,
) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final lines = [
    header.map(cell).join(','),
    for (final r in rows) r.map(cell).join(','),
  ];
  final csv = '﻿${lines.join('\n')}';
  return saveBytesAs(fileName, Uint8List.fromList(utf8.encode(csv)));
}
