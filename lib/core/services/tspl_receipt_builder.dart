import 'dart:convert';
import 'dart:typed_data';

import '../../data/json_helpers.dart';
import '../../data/models/invoice.dart';
import 'tspl_logo_bitmap.dart';
import 'tspl_logo_loader_stub.dart'
    if (dart.library.ui) 'tspl_logo_loader_io.dart' as logo_loader;
import 'tspl_times_renderer_stub.dart'
    if (dart.library.ui) 'tspl_times_renderer_io.dart' as times_font;

/// Builds TSPL command bytes for a 203 dpi USB thermal printer (XP-470B).
///
/// 70 mm CASH BILL — larger Times New Roman with fixed column alignment.
class TsplReceiptBuilder {
  TsplReceiptBuilder._();

  static const int dpi = 203;
  static const int dotsPerMm = 8;
  static const int receiptWidthMm = 70;

  /// Pull content left (70 mm gap printers leave a left dead-zone).
  static const int _shiftLeftDots = 80; // ≈ 10 mm
  static const int _amtRightPadDots = 10;
  /// Date / Time sit on the right (small pad from paper edge).
  static const int _metaRightPadDots = 16;
  static const int _marginX = 0;
  /// ~2.0 pt leading between rows (+1 pt extra @ 203 dpi ≈ 5.6 dots).
  static const int _lineGap = 6;
  /// Height of an intentional blank spacer row.
  static const int _blankRowDots = 6;

  /// Times New Roman sizes (px ≈ dots @ 203 dpi).
  static const double bodyFontPt = 26;
  static const double titleFontPt = 32;

  /// Style markers (body vs title).
  static const int bodyFont = 1;
  static const int titleFont = 2;

  static Future<Uint8List> build({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    int? paperWidthMm,
    bool includeLogo = true,
  }) async {
    const widthMm = receiptWidthMm;
    final widthDots = widthMm * dotsPerMm;
    final layout = _ColumnLayout(widthDots);
    final cols = layout.addressCols;
    final lines = <_TsplLine>[];

    for (final title in _headerTitleLines(shopName)) {
      lines.add(_TsplLine(title, font: titleFont, align: _Align.center));
    }
    lines.add(const _TsplLine(''));

    final address = (shopAddress ?? '').trim();
    if (address.isNotEmpty) {
      for (final part in _wrapAddress(address, cols)) {
        lines.add(_TsplLine(part, align: _Align.center));
      }
    }
    final phone = (shopPhone ?? '').trim();
    if (phone.isNotEmpty) {
      lines.add(_TsplLine('Ph :$phone', align: _Align.center));
    }
    final gstin = (shopGstin ?? '').trim();
    if (gstin.isNotEmpty) {
      lines.add(_TsplLine('GST No :$gstin', align: _Align.center));
    }
    lines.add(const _TsplLine(''));
    lines.add(
      _TsplLine(_billTitle(invoice), font: titleFont, align: _Align.center),
    );
    lines.add(const _TsplLine(''));

    final biller = (billerName ?? '').trim();
    final billNo = invoice.displayInvoiceNumber.trim();
    final dateStr = _billDate(invoice);
    final timeStr = _billTime(invoice);
    final customerName = invoice.customer?.name.trim() ?? '';

    // Left: Biller / Bill NO / Customer — Right: Date / Time
    lines.add(
      _TsplLine(
        biller.isEmpty ? '' : 'Biller : $biller',
        rightText: 'Date : $dateStr',
      ),
    );
    if (billNo.isNotEmpty || timeStr.isNotEmpty) {
      lines.add(
        _TsplLine(
          billNo.isEmpty ? '' : 'Bill NO. : $billNo',
          rightText: timeStr.isEmpty ? null : 'Time : $timeStr',
        ),
      );
    }
    if (customerName.isNotEmpty) {
      lines.add(_TsplLine('Cus Name : $customerName'));
    }
    lines.add(const _TsplLine(''));

    lines.add(_TsplLine.rule(layout.ruleWidthDots));
    lines.add(
      _TsplLine.item(
        sno: 'No',
        name: 'Particulars',
        mrp: 'MRP',
        price: 'Price',
        qty: 'Qty',
        amt: 'Amt',
      ),
    );
    lines.add(_TsplLine.rule(layout.ruleWidthDots));

    var sno = 1;
    for (final item in items) {
      final mrp = item.mrp > 0 ? item.mrp : item.unitPrice;
      lines.add(
        _TsplLine.item(
          sno: '$sno.',
          name: item.productName,
          mrp: _money(mrp),
          price: _money(item.unitPrice),
          qty: _qty(item.quantity),
          amt: _money(item.totalAmount),
        ),
      );
      sno++;
    }
    lines.add(_TsplLine.rule(layout.ruleWidthDots));

    lines.add(
      _TsplLine(
        'Bill Amount : ${_money(invoice.totalAmount)}',
        font: titleFont,
        align: _Align.right,
        pinRight: true,
      ),
    );
    lines.add(_TsplLine('No Of Items :${items.length}'));
    lines.add(_TsplLine('Grand Total : ${_money(invoice.totalAmount)}'));
    lines.add(const _TsplLine(''));
    lines.add(
      _TsplLine('**** We care for your pet ****', align: _Align.center),
    );
    // Tear margin.
    lines.add(const _TsplLine(''));
    lines.add(const _TsplLine(''));
    lines.add(const _TsplLine(''));

    return _encodeBytes(
      widthMm: widthMm,
      widthDots: widthDots,
      lines: lines,
      includeLogo: includeLogo,
    );
  }

  static Future<Uint8List> buildSample({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    bool includeLogo = true,
  }) async {
    return buildSampleBytes(
      shopName: shopName,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
      includeLogo: includeLogo,
    );
  }

  static Future<String> buildSampleCommands({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
  }) async {
    final bytes = await buildSampleBytes(
      shopName: shopName,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
      includeLogo: false,
    );
    final text = latin1.decode(bytes, allowInvalid: true);
    return 'BITMAP (logo)\r\n$text';
  }

  static Future<Uint8List> buildSampleBytes({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    bool includeLogo = true,
  }) async {
    const widthMm = receiptWidthMm;
    final widthDots = widthMm * dotsPerMm;
    final layout = _ColumnLayout(widthDots);
    final cols = layout.addressCols;
    final lines = <_TsplLine>[];

    for (final title in _headerTitleLines(
      shopName.trim().isEmpty ? 'Maran Veterinary Hospital' : shopName,
    )) {
      lines.add(_TsplLine(title, font: titleFont, align: _Align.center));
    }
    lines.add(const _TsplLine(''));

    final address = (shopAddress ??
            'Vimaladevi Complex, Kanji Road, Vengikkal, Tiruvannamalai.')
        .trim();
    for (final part in _wrapAddress(address, cols)) {
      lines.add(_TsplLine(part, align: _Align.center));
    }
    lines.add(
      _TsplLine(
        'Ph :${(shopPhone ?? '9488350208').trim()}',
        align: _Align.center,
      ),
    );
    final gstin = (shopGstin ?? '').trim();
    if (gstin.isNotEmpty) {
      lines.add(_TsplLine('GST No :$gstin', align: _Align.center));
    }
    lines.add(const _TsplLine(''));
    lines.add(_TsplLine('CASH BILL', font: titleFont, align: _Align.center));
    lines.add(const _TsplLine(''));

    final biller = (billerName ?? 'user1').trim();
    lines.add(
      _TsplLine('Biller : $biller', rightText: 'Date : 26.10.2025'),
    );
    lines.add(
      _TsplLine('Bill NO. : 20-21/46916', rightText: 'Time : 12:35 PM'),
    );
    lines.add(_TsplLine('Cus Name : sivaraman'));
    lines.add(const _TsplLine(''));

    lines.add(_TsplLine.rule(layout.ruleWidthDots));
    lines.add(
      _TsplLine.item(
        sno: 'No',
        name: 'Particulars',
        mrp: 'MRP',
        price: 'Price',
        qty: 'Qty',
        amt: 'Amt',
      ),
    );
    lines.add(_TsplLine.rule(layout.ruleWidthDots));

    final sampleItems =
        <({String name, String mrp, String price, String qty, String amt})>[
      (
        name: 'Recombitek C4',
        mrp: '820.00',
        price: '650.00',
        qty: '1',
        amt: '650.00',
      ),
      (
        name: 'Deworming',
        mrp: '50.00',
        price: '50.00',
        qty: '1',
        amt: '50.00',
      ),
      (
        name: 'Treatment (P4)',
        mrp: '250.00',
        price: '250.00',
        qty: '1',
        amt: '250.00',
      ),
      (
        name: 'skyworm dog.',
        mrp: '52.00',
        price: '50.00',
        qty: '1',
        amt: '50.00',
      ),
      (name: 'belt', mrp: '60.00', price: '57.00', qty: '1', amt: '57.00'),
      (
        name: 'Brass Hook Chain No.1',
        mrp: '220.00',
        price: '210.00',
        qty: '1',
        amt: '210.00',
      ),
    ];
    for (var i = 0; i < sampleItems.length; i++) {
      final it = sampleItems[i];
      lines.add(
        _TsplLine.item(
          sno: '${i + 1}.',
          name: it.name,
          mrp: it.mrp,
          price: it.price,
          qty: it.qty,
          amt: it.amt,
        ),
      );
    }
    lines.add(_TsplLine.rule(layout.ruleWidthDots));
    lines.add(
      _TsplLine(
        'Bill Amount : 1267.00',
        font: titleFont,
        align: _Align.right,
        pinRight: true,
      ),
    );
    lines.add(_TsplLine('No Of Items :6'));
    lines.add(_TsplLine('Grand Total : 1267.00'));
    lines.add(const _TsplLine(''));
    lines.add(
      _TsplLine('**** We care for your pet ****', align: _Align.center),
    );
    lines.add(const _TsplLine(''));
    lines.add(const _TsplLine(''));
    lines.add(const _TsplLine(''));

    return _encodeBytes(
      widthMm: widthMm,
      widthDots: widthDots,
      lines: lines,
      includeLogo: includeLogo,
    );
  }

  static List<String> _headerTitleLines(String? shopName) {
    final raw = (shopName ?? 'Maran Veterinary Hospital').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('veterinary')) {
      return const ['MARAN', 'VETERINARY HOSPITAL'];
    }
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return [
        parts.first.toUpperCase(),
        parts.sublist(1).join(' ').toUpperCase(),
      ];
    }
    return [raw.toUpperCase()];
  }

  static String _billTitle(Invoice invoice) {
    final payments = invoice.payments ?? const <InvoicePayment>[];
    final hasCash = payments.any((p) => p.paymentMode.toLowerCase() == 'cash');
    if (invoice.dueAmount > 0.009) return 'CREDIT BILL';
    if (hasCash || invoice.isPaid) return 'CASH BILL';
    return 'CASH BILL';
  }

  static String _billDate(Invoice invoice) {
    final raw = invoice.createdAt ?? invoice.invoiceDate;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final y = parsed.year.toString().padLeft(4, '0');
      return '$d.$m.$y';
    }
    final api = formatApiDate(invoice.invoiceDate);
    final bits = api.split('-');
    if (bits.length == 3) return '${bits[2]}.${bits[1]}.${bits[0]}';
    return api;
  }

  static String _billTime(Invoice invoice) {
    final raw = invoice.createdAt;
    if (raw == null || raw.isEmpty) {
      return _formatTime12(DateTime.now());
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    return _formatTime12(parsed.toLocal());
  }

  static String _formatTime12(DateTime dt) {
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:$minute $period';
  }

  static double _fontSize(int font) =>
      font == titleFont ? titleFontPt : bodyFontPt;

  static Future<Uint8List> _encodeBytes({
    required int widthMm,
    required int widthDots,
    required List<_TsplLine> lines,
    required bool includeLogo,
  }) async {
    const marginX = _marginX;
    const marginY = 8;
    final centerWidth = widthDots - _amtRightPadDots;
    final layout = _ColumnLayout(widthDots);
    final useTimes = times_font.TsplTimesRenderer.isSupported;

    var logoHeight = 0;
    Uint8List? logoCmd;
    if (includeLogo) {
      await logo_loader.ensureTsplLogoLoaded();
      logoCmd = TsplLogoBitmap.buildCommand(x: 0, y: marginY);
      logoHeight = TsplLogoBitmap.heightDots;
      if (logoCmd != null && logoHeight > 0) {
        final logoW = TsplLogoBitmap.widthDots.clamp(0, centerWidth);
        final logoX = ((centerWidth - logoW) / 2).round().clamp(0, centerWidth);
        logoCmd = TsplLogoBitmap.buildCommand(x: logoX, y: marginY);
      }
    }

    final logoGap = logoCmd == null ? 0 : logoHeight + 6;

    final rendered = <_RenderedLine>[];
    var contentHeight = 0;
    for (final line in lines) {
      if (line.text.isEmpty &&
          line.rightText == null &&
          line.item == null &&
          line.ruleWidthDots == null) {
        rendered.add(const _RenderedLine.blank(_blankRowDots));
        contentHeight += _blankRowDots;
        continue;
      }

      final size = _fontSize(line.font);
      final bold = line.font == titleFont;

      if (line.ruleWidthDots != null) {
        final dashCount = (line.ruleWidthDots! / (bodyFontPt * 0.35))
            .floor()
            .clamp(8, 80);
        final ruleText = '-' * dashCount;
        times_font.TsplTimesGlyph? glyph;
        if (useTimes) {
          glyph = await times_font.TsplTimesRenderer.render(
            text: ruleText,
            fontSize: bodyFontPt,
            maxWidthDots: line.ruleWidthDots,
          );
        }
        final h = glyph?.heightDots ?? _charHeight(bodyFont);
        rendered.add(
          _RenderedLine(
            source: line,
            leftGlyph: glyph,
            heightDots: h + _lineGap,
          ),
        );
        contentHeight += h + _lineGap;
        continue;
      }

      if (line.item != null) {
        final item = line.item!;
        final cells = <_PlacedGlyph>[];
        var rowH = _charHeight(bodyFont);

        Future<void> placeLeft(String text, int x, int maxW) async {
          if (text.isEmpty) return;
          if (useTimes) {
            final g = await times_font.TsplTimesRenderer.render(
              text: text,
              fontSize: size,
              bold: bold,
              maxWidthDots: maxW,
            );
            if (g != null) {
              cells.add(_PlacedGlyph(x: x, glyph: g));
              if (g.heightDots > rowH) rowH = g.heightDots;
            }
          } else {
            // Fallback TEXT placed later via left/right strings.
          }
        }

        Future<void> placeRight(String text, int rightEdge, int maxW) async {
          if (text.isEmpty) return;
          if (useTimes) {
            final g = await times_font.TsplTimesRenderer.render(
              text: text,
              fontSize: size,
              bold: bold,
              maxWidthDots: maxW,
            );
            if (g != null) {
              final x = (rightEdge - g.widthDots).clamp(0, rightEdge);
              cells.add(_PlacedGlyph(x: x, glyph: g));
              if (g.heightDots > rowH) rowH = g.heightDots;
            }
          }
        }

        await placeLeft(item.sno, layout.snoX, layout.snoW);
        await placeLeft(item.name, layout.nameX, layout.nameW);
        await placeRight(item.mrp, layout.mrpRight, layout.numW);
        await placeRight(item.price, layout.priceRight, layout.numW);
        await placeRight(item.qty, layout.qtyRight, layout.qtyW);
        await placeRight(item.amt, layout.amtRight, layout.amtW);

        // Fallback single-line when Times unavailable.
        String? fallback;
        if (!useTimes) {
          fallback =
              '${item.sno} ${item.name} ${item.mrp} ${item.price} ${item.qty}';
        }

        rendered.add(
          _RenderedLine(
            source: line.copyWithText(fallback ?? ''),
            cells: cells,
            rightGlyph: null,
            heightDots: rowH + _lineGap,
            fallbackRight: useTimes ? null : item.amt,
            pinRightFallback: true,
          ),
        );
        contentHeight += rowH + _lineGap;
        continue;
      }

      times_font.TsplTimesGlyph? leftGlyph;
      times_font.TsplTimesGlyph? rightGlyph;
      if (useTimes) {
        if (line.text.isNotEmpty) {
          leftGlyph = await times_font.TsplTimesRenderer.render(
            text: line.text,
            fontSize: size,
            bold: bold,
            maxWidthDots: line.rightText != null
                ? widthDots - _metaRightPadDots - 80
                : centerWidth,
          );
        }
        if (line.rightText != null && line.rightText!.isNotEmpty) {
          rightGlyph = await times_font.TsplTimesRenderer.render(
            text: line.rightText!,
            fontSize: size,
            bold: bold,
          );
        }
      }

      final rowH = [
        leftGlyph?.heightDots ?? _charHeight(line.font),
        rightGlyph?.heightDots ?? 0,
        _charHeight(line.font),
      ].reduce((a, b) => a > b ? a : b);

      rendered.add(
        _RenderedLine(
          source: line,
          leftGlyph: leftGlyph,
          rightGlyph: rightGlyph,
          heightDots: rowH + _lineGap,
        ),
      );
      contentHeight += rowH + _lineGap;
    }

    final heightDots = contentHeight + marginY * 2 + logoGap + 24;
    final heightMm = ((heightDots / dotsPerMm).ceil()).clamp(50, 800);

    final cmd = BytesBuilder(copy: false);
    void writeAscii(String s) => cmd.add(utf8.encode('$s\r\n'));

    writeAscii('SIZE $widthMm mm, $heightMm mm');
    writeAscii('GAP 0 mm, 0 mm');
    writeAscii('DIRECTION 1');
    writeAscii('REFERENCE -$_shiftLeftDots,0');
    writeAscii('SET TEAR ON');
    writeAscii('CLS');

    if (logoCmd != null) {
      cmd.add(logoCmd);
    }

    var y = marginY + logoGap;
    for (final row in rendered) {
      if (row.isBlank) {
        y += row.heightDots;
        continue;
      }

      final line = row.source!;
      final charW = _charWidth(line.font);

      // Fixed-column item row.
      if (row.cells != null && row.cells!.isNotEmpty) {
        for (final cell in row.cells!) {
          _writeBitmap(cmd, x: cell.x, y: y, glyph: cell.glyph);
        }
        y += row.heightDots;
        continue;
      }

      if (line.rightText != null || row.fallbackRight != null) {
        final rightPad =
            (line.pinRight || row.pinRightFallback)
                ? _amtRightPadDots
                : _metaRightPadDots;
        final rightEdge = widthDots - rightPad;
        final rightText = row.fallbackRight ?? line.rightText!;

        if (row.leftGlyph != null) {
          _writeBitmap(cmd, x: marginX, y: y, glyph: row.leftGlyph!);
        } else if (line.text.isNotEmpty) {
          var left = _escape(line.text);
          final rightDots = rightText.length * charW;
          final rx = (rightEdge - rightDots).clamp(0, rightEdge);
          final maxLeftChars =
              ((rx - 12) / charW).floor().clamp(1, left.length);
          if (left.length > maxLeftChars) {
            left = left.substring(0, maxLeftChars);
          }
          writeAscii('TEXT $marginX,$y,"${line.font}",0,1,1,"$left"');
        }

        if (row.rightGlyph != null) {
          final rx =
              (rightEdge - row.rightGlyph!.widthDots).clamp(0, rightEdge);
          _writeBitmap(cmd, x: rx, y: y, glyph: row.rightGlyph!);
        } else {
          final right = _escape(rightText);
          final rightDots = right.length * charW;
          final rx = (rightEdge - rightDots).clamp(0, rightEdge);
          writeAscii('TEXT $rx,$y,"${line.font}",0,1,1,"$right"');
        }
      } else if (row.leftGlyph != null) {
        final g = row.leftGlyph!;
        final int x;
        switch (line.align) {
          case _Align.center:
            x = ((centerWidth - g.widthDots) / 2).round().clamp(0, centerWidth);
          case _Align.right:
            final edge = line.pinRight
                ? widthDots - _amtRightPadDots
                : widthDots - _metaRightPadDots;
            x = (edge - g.widthDots - marginX).clamp(0, edge);
          case _Align.left:
            x = marginX;
        }
        _writeBitmap(cmd, x: x, y: y, glyph: g);
      } else if (line.text.isNotEmpty) {
        final text = _escape(line.text);
        final textDots = text.length * charW;
        final int x;
        switch (line.align) {
          case _Align.center:
            x = ((centerWidth - textDots) / 2).round().clamp(0, centerWidth);
          case _Align.right:
            final edge = line.pinRight
                ? widthDots - _amtRightPadDots
                : widthDots - _metaRightPadDots;
            x = (edge - textDots - marginX).clamp(0, edge);
          case _Align.left:
            x = marginX;
        }
        writeAscii('TEXT $x,$y,"${line.font}",0,1,1,"$text"');
      }
      y += row.heightDots;
    }

    writeAscii('PRINT 1,1');
    return cmd.toBytes();
  }

  static void _writeBitmap(
    BytesBuilder cmd, {
    required int x,
    required int y,
    required times_font.TsplTimesGlyph glyph,
  }) {
    final header =
        'BITMAP $x,$y,${glyph.widthBytes},${glyph.heightDots},0,';
    cmd
      ..add(utf8.encode(header))
      ..add(glyph.packed)
      ..add(const [0x0D, 0x0A]);
  }

  static int _charWidth(int font) {
    final size = _fontSize(font);
    return (size * 0.45).round().clamp(6, 16);
  }

  static int _charHeight(int font) {
    return (_fontSize(font) * 1.1).round().clamp(16, 36);
  }

  static String _money(double amount) => amount.toStringAsFixed(2);

  static String _qty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(1);
  }

  static List<String> _wrapAddress(String text, int cols) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= cols) return [cleaned];

    final byComma = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (byComma.length >= 2) {
      final out = <String>[];
      var current = byComma.first;
      for (var i = 1; i < byComma.length; i++) {
        final next = byComma[i];
        final candidate = '$current, $next';
        if (candidate.length <= cols) {
          current = candidate;
        } else {
          out.add(current.endsWith(',') ? current : '$current,');
          current = next;
        }
      }
      if (current.isNotEmpty) {
        out.add(current.endsWith('.') ? current : '$current.');
      }
      return out.expand((line) => _wrap(line, cols)).toList();
    }
    return _wrap(cleaned, cols);
  }

  static List<String> _wrap(String text, int cols) {
    if (text.length <= cols) return [text];
    final out = <String>[];
    var rest = text;
    while (rest.length > cols) {
      out.add(rest.substring(0, cols));
      rest = rest.substring(cols);
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  static String _escape(String value) {
    return value
        .replaceAll('"', "'")
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
  }
}

/// Fixed X positions so Times (proportional) columns stay aligned.
class _ColumnLayout {
  _ColumnLayout(this.widthDots)
      : amtRight = widthDots - TsplReceiptBuilder._amtRightPadDots,
        amtW = 98,
        qtyW = 44,
        numW = 90,
        snoX = 0,
        snoW = 44 {
    qtyRight = amtRight - amtW - 10;
    priceRight = qtyRight - qtyW - 10;
    mrpRight = priceRight - numW - 10;
    nameX = snoW + 4;
    nameW = (mrpRight - numW - 10 - nameX).clamp(80, widthDots);
    ruleWidthDots = amtRight;
    addressCols = (widthDots / (TsplReceiptBuilder.bodyFontPt * 0.42))
        .floor()
        .clamp(24, 42);
  }

  final int widthDots;
  final int snoX;
  final int snoW;
  late final int nameX;
  late final int nameW;
  late final int mrpRight;
  late final int priceRight;
  late final int qtyRight;
  final int amtRight;
  final int amtW;
  final int qtyW;
  final int numW;
  late final int ruleWidthDots;
  late final int addressCols;
}

enum _Align { left, center, right }

class _ItemCols {
  const _ItemCols({
    required this.sno,
    required this.name,
    required this.mrp,
    required this.price,
    required this.qty,
    required this.amt,
  });

  final String sno;
  final String name;
  final String mrp;
  final String price;
  final String qty;
  final String amt;
}

class _TsplLine {
  const _TsplLine(
    this.text, {
    this.font = TsplReceiptBuilder.bodyFont,
    this.align = _Align.left,
    this.rightText,
    this.pinRight = false,
    this.item,
    this.ruleWidthDots,
  });

  factory _TsplLine.item({
    required String sno,
    required String name,
    required String mrp,
    required String price,
    required String qty,
    required String amt,
  }) {
    return _TsplLine(
      '',
      item: _ItemCols(
        sno: sno,
        name: name,
        mrp: mrp,
        price: price,
        qty: qty,
        amt: amt,
      ),
    );
  }

  factory _TsplLine.rule(int widthDots) {
    return _TsplLine('', ruleWidthDots: widthDots);
  }

  final String text;
  final int font;
  final _Align align;
  final String? rightText;
  final bool pinRight;
  final _ItemCols? item;
  final int? ruleWidthDots;

  _TsplLine copyWithText(String value) {
    return _TsplLine(
      value,
      font: font,
      align: align,
      rightText: rightText,
      pinRight: pinRight,
      item: item,
      ruleWidthDots: ruleWidthDots,
    );
  }
}

class _PlacedGlyph {
  const _PlacedGlyph({required this.x, required this.glyph});

  final int x;
  final times_font.TsplTimesGlyph glyph;
}

class _RenderedLine {
  const _RenderedLine({
    required this.source,
    this.leftGlyph,
    this.rightGlyph,
    this.cells,
    required this.heightDots,
    this.fallbackRight,
    this.pinRightFallback = false,
  }) : isBlank = false;

  const _RenderedLine.blank(this.heightDots)
      : source = null,
        leftGlyph = null,
        rightGlyph = null,
        cells = null,
        fallbackRight = null,
        pinRightFallback = false,
        isBlank = true;

  final _TsplLine? source;
  final times_font.TsplTimesGlyph? leftGlyph;
  final times_font.TsplTimesGlyph? rightGlyph;
  final List<_PlacedGlyph>? cells;
  final int heightDots;
  final bool isBlank;
  final String? fallbackRight;
  final bool pinRightFallback;
}
