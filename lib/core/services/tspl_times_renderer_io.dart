import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Renders receipt text with Windows **Times New Roman** into a TSPL 1-bit glyph.
///
/// TSPL bit convention: **0** = black (print), **1** = white.
abstract final class TsplTimesRenderer {
  static bool get isSupported => true;

  static var _warmed = false;

  static Future<void> warmCommon() async {
    if (_warmed) return;
    _warmed = true;
    const body = 26.0;
    const title = 32.0;
    await Future.wait([
      render(text: 'Particulars', fontSize: body),
      render(text: 'MRP', fontSize: body),
      render(text: 'Price', fontSize: body),
      render(text: 'Qty', fontSize: body),
      render(text: 'Amt', fontSize: body),
      render(text: 'No', fontSize: body),
      render(text: 'No Of Items :1', fontSize: body),
      render(text: '**** We care for your pet ****', fontSize: body),
      render(text: 'Grand Total : 0.00', fontSize: body),
      render(text: 'Bill Amount : 0.00', fontSize: title, bold: true),
      render(text: '-' * 40, fontSize: body, maxWidthDots: 480),
    ]);
  }

  static const int _maxCacheEntries = 256;
  static final Map<String, TsplTimesGlyph> _cache = {};

  static String _cacheKey({
    required String text,
    required double fontSize,
    required bool bold,
    required int? maxWidthDots,
  }) =>
      '$fontSize|${bold ? 1 : 0}|${maxWidthDots ?? 0}|$text';

  static Future<TsplTimesGlyph?> render({
    required String text,
    required double fontSize,
    bool bold = false,
    int? maxWidthDots,
  }) async {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return null;

    final key = _cacheKey(
      text: trimmed,
      fontSize: fontSize,
      bold: bold,
      maxWidthDots: maxWidthDots,
    );
    final cached = _cache[key];
    if (cached != null) return cached;

    final glyph = await _rasterize(
      trimmed: trimmed,
      fontSize: fontSize,
      bold: bold,
      maxWidthDots: maxWidthDots,
    );
    if (glyph == null) return null;

    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = glyph;
    return glyph;
  }

  static Future<TsplTimesGlyph?> _rasterize({
    required String trimmed,
    required double fontSize,
    required bool bold,
    required int? maxWidthDots,
  }) async {
    final weight = bold ? ui.FontWeight.w600 : ui.FontWeight.w400;
    const family = 'Times New Roman';
    final layoutW = (maxWidthDots ?? 2000).toDouble();

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        fontFamily: family,
        fontSize: fontSize,
        fontWeight: weight,
        maxLines: 1,
        ellipsis: '…',
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xFF000000),
          fontFamily: family,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.0,
        ),
      )
      ..addText(trimmed);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: layoutW));

    final intrinsic = paragraph.maxIntrinsicWidth.ceil().clamp(1, 560);
    final w = maxWidthDots == null
        ? intrinsic
        : intrinsic.clamp(1, maxWidthDots);
    final h = paragraph.height.ceil().clamp(1, 140);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) return null;

    final widthBytes = (w + 7) ~/ 8;
    final packed = Uint8List(widthBytes * h)..fillRange(0, widthBytes * h, 0xFF);
    final rgba = bytes.buffer.asUint8List();

    for (var row = 0; row < h; row++) {
      for (var col = 0; col < w; col++) {
        final i = (row * w + col) * 4;
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        // Crush anti-alias gray → solid black for thermal.
        final lum = (0.299 * r + 0.587 * g + 0.114 * b);
        if (lum > 160) continue;
        final byteIndex = row * widthBytes + (col >> 3);
        packed[byteIndex] &= ~(0x80 >> (col & 7));
      }
    }

    return TsplTimesGlyph(
      packed: packed,
      widthDots: w,
      heightDots: h,
      widthBytes: widthBytes,
    );
  }
}

class TsplTimesGlyph {
  const TsplTimesGlyph({
    required this.packed,
    required this.widthDots,
    required this.heightDots,
    required this.widthBytes,
  });

  final Uint8List packed;
  final int widthDots;
  final int heightDots;
  final int widthBytes;
}
