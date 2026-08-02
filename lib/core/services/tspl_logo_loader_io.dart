import 'package:flutter/services.dart' show rootBundle;

import 'tspl_logo_bitmap.dart';

/// Loads the **receipt-only** black logo into [TsplLogoBitmap.pngBytes].
///
/// UI branding still uses [assets/branding/logo.png] via [AppLogo].
Future<void> ensureTsplLogoLoaded() async {
  try {
    final data = await rootBundle.load('assets/branding/receipt-logo.png');
    // Always refresh so conversion picks up the latest asset/logic.
    TsplLogoBitmap.clearCache();
    TsplLogoBitmap.pngBytes = data.buffer.asUint8List();
  } catch (_) {
    // Asset missing — receipt prints without logo.
  }
}
