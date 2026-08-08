import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Converts a PNG logo to a TSPL BITMAP payload (1-bit, solid black only).
///
/// TSPL convention: bit **0** = black (print), bit **1** = white (no print).
class TsplLogoBitmap {
  TsplLogoBitmap._();

  /// Max logo width in dots (~22 mm @ 203 dpi).
  static const int maxWidthDots = 176;

  /// Optional PNG bytes (set by app/CLI before build).
  static Uint8List? pngBytes;

  static Uint8List? _cachedPacked;
  static int? _cachedHeight;
  static int? _cachedWidthBytes;
  static int? _cachedWidthDots;

  static int get widthDots => _cachedWidthDots ?? maxWidthDots;
  static int get heightDots => _cachedHeight ?? 0;

  /// Returns `BITMAP x,y,w,h,0,` + raw bits + CRLF, or null if no logo.
  static Uint8List? buildCommand({
    required int x,
    required int y,
  }) {
    if (pngBytes == null || pngBytes!.isEmpty) return null;

    if (_cachedPacked == null) {
      final decoded = img.decodeImage(pngBytes!);
      if (decoded == null) return null;

      // LA (grayscale+alpha) PNGs are 2-channel; resize/filters corrupt them.
      // Normalize to RGBA before any processing so alpha + luminance stay correct.
      final rgba = decoded.numChannels == 4
          ? decoded
          : decoded.convert(numChannels: 4);

      // Nearest resize keeps hard edges (no gray anti-alias for thermal).
      var work = img.copyResize(
        rgba,
        width: maxWidthDots,
        interpolation: img.Interpolation.nearest,
      );
      work = img.grayscale(work);
      // Crush mid-tones so ink is solid black vs white paper only.
      // (image.adjustColor clamps contrast to 0..2; 2 = max push.)
      work = img.adjustColor(work, contrast: 2);

      final w = work.width;
      final h = work.height;
      final widthBytes = (w + 7) ~/ 8;
      // All white (0xFF); clear bits → solid black print.
      final packed = Uint8List(widthBytes * h);
      packed.fillRange(0, packed.length, 0xFF);

      for (var row = 0; row < h; row++) {
        for (var col = 0; col < w; col++) {
          final p = work.getPixel(col, row);
          // Transparent / white → no ink (paper).
          if (p.a < 128) continue;
          final lum =
              img.getLuminanceRgb(p.r.toInt(), p.g.toInt(), p.b.toInt());
          // Black silhouette receipt logo: dark pixels print as solid black.
          if (lum >= 200) continue;
          final byteIndex = row * widthBytes + (col >> 3);
          packed[byteIndex] &= ~(0x80 >> (col & 7));
        }
      }

      _cachedPacked = packed;
      _cachedHeight = h;
      _cachedWidthBytes = widthBytes;
      _cachedWidthDots = w;
    }

    final packed = _cachedPacked!;
    final height = _cachedHeight!;
    final widthBytes = _cachedWidthBytes!;
    final header = 'BITMAP $x,$y,$widthBytes,$height,0,';
    return (BytesBuilder(copy: false)
          ..add(header.codeUnits)
          ..add(packed)
          ..add(const [0x0D, 0x0A]))
        .toBytes();
  }

  static void clearCache() {
    _cachedPacked = null;
    _cachedHeight = null;
    _cachedWidthBytes = null;
    _cachedWidthDots = null;
  }
}
