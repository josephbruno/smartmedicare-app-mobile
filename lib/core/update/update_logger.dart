import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UpdateLogger {
  UpdateLogger._();

  static Future<File> _file() async {
    final dir = Directory(
      p.join(
        Platform.environment['LOCALAPPDATA'] ??
            (await getTemporaryDirectory()).path,
        'MaranBilling',
        'logs',
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'update.log'));
  }

  static Future<void> log(String message) async {
    try {
      final f = await _file();
      final line = '${DateTime.now().toUtc().toIso8601String()} $message\n';
      await f.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break update flow.
    }
  }
}
