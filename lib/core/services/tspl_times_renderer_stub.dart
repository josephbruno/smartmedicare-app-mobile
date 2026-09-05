import 'dart:typed_data';

/// Stub when `dart:ui` is unavailable (plain `dart run` tools).
abstract final class TsplTimesRenderer {
  static bool get isSupported => false;

  static Future<void> warmCommon() async {}

  static Future<TsplTimesGlyph?> render({
    required String text,
    required double fontSize,
    bool bold = false,
    int? maxWidthDots,
  }) async =>
      null;
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
