import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../data/json_helpers.dart';
import '../../data/models/invoice.dart';
import 'tspl_logo_bitmap.dart';
import 'tspl_logo_loader_stub.dart'
    if (dart.library.ui) 'tspl_logo_loader_io.dart' as logo_loader;
import 'tspl_times_renderer_stub.dart'
    if (dart.library.ui) 'tspl_times_renderer_io.dart' as times_font;

/// Builds ESC/POS bytes for an 80 mm USB receipt printer (Retsol RTP 80).
///
/// Receipt content and Times New Roman layout match [TsplReceiptBuilder]
/// (Branch 1 XPrinter). Only the wire encoding is ESC/POS.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  /// 80 mm roll, 203 dpi — 72 mm printable (576 dots) on most ESC/POS heads.
  static const int dpi = 203;
  static const int dotsPerMm = 8;
  static const int receiptWidthMm = 80;
  static const int widthDots = 576;

  static const int _amtRightPadDots = 10;
  static const int _metaRightPadDots = 16;
  static const int _marginX = 0;
  static const int _lineGap = 6;
  static const int _blankRowDots = 6;

  static const double bodyFontPt = 26;
  static const double titleFontPt = 32;
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
    bool includeLogo = true,
  }) async {
    final layout = _ColumnLayout(widthDots);
    final lines = <_EscPosLine>[];

    for (final title in _headerTitleLines(shopName)) {
      lines.add(_EscPosLine(title, font: titleFont, align: _Align.center));
    }
    lines.add(const _EscPosLine(''));

    final address = (shopAddress ?? '').trim();
    if (address.isNotEmpty) {
      for (final part in _addressTwoLines(address)) {
        lines.add(_EscPosLine(part, align: _Align.center));
      }
    }
    final phone = (shopPhone ?? '').trim();
    if (phone.isNotEmpty) {
      lines.add(_EscPosLine('Ph :$phone', align: _Align.center));
    }
    final gstin = (shopGstin ?? '').trim();
    if (gstin.isNotEmpty) {
      lines.add(_EscPosLine('GST No :$gstin', align: _Align.center));
    }
    lines.add(const _EscPosLine(''));
    lines.add(
      _EscPosLine(_billTitle(invoice), font: titleFont, align: _Align.center),
    );
    lines.add(const _EscPosLine(''));

    final biller = (billerName ?? '').trim();
    final billNo = invoice.displayInvoiceNumber.trim();
    final dateStr = _billDate(invoice);
    final timeStr = _billTime(invoice);
    final customerName = invoice.customer?.name.trim() ?? '';

    lines.add(
      _EscPosLine(
        biller.isEmpty ? '' : 'Biller : $biller',
        rightText: 'Date : $dateStr',
      ),
    );
    if (billNo.isNotEmpty || timeStr.isNotEmpty) {
      lines.add(
        _EscPosLine(
          billNo.isEmpty ? '' : 'Bill NO. : $billNo',
          rightText: timeStr.isEmpty ? null : 'Time : $timeStr',
        ),
      );
    }
    if (customerName.isNotEmpty) {
      lines.add(_EscPosLine('Cus Name : $customerName'));
    }
    lines.add(const _EscPosLine(''));

    lines.add(_EscPosLine.rule(layout.ruleWidthDots));
    lines.add(
      _EscPosLine.item(
        sno: 'No',
        name: 'Particulars',
        mrp: 'MRP',
        price: 'Price',
        qty: 'Qty',
        amt: 'Amt',
      ),
    );
    lines.add(_EscPosLine.rule(layout.ruleWidthDots));

    var sno = 1;
    for (final item in items) {
      final mrp = item.mrp > 0 ? item.mrp : item.unitPrice;
      lines.add(
        _EscPosLine.item(
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
    lines.add(_EscPosLine.rule(layout.ruleWidthDots));

    lines.add(
      _EscPosLine(
        'Bill Amount : ${_money(invoice.totalAmount)}',
        font: titleFont,
        align: _Align.right,
        pinRight: true,
      ),
    );
    lines.add(_EscPosLine('No Of Items :${items.length}'));
    lines.add(_EscPosLine('Grand Total : ${_money(invoice.totalAmount)}'));
    lines.add(const _EscPosLine(''));
    lines.add(
      _EscPosLine('**** We care for your pet ****', align: _Align.center),
    );
    lines.add(const _EscPosLine(''));
    lines.add(const _EscPosLine(''));
    lines.add(const _EscPosLine(''));

    return _encodeBytes(lines: lines, includeLogo: includeLogo);
  }

  static Future<EscPosSampleBuild> buildSample({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    bool includeLogo = true,
  }) async {
    final bytes = await buildSampleBytes(
      shopName: shopName,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      shopAddress: shopAddress,
      billerName: billerName,
      includeLogo: includeLogo,
    );
    return EscPosSampleBuild(
      bytes: bytes,
      preview: _samplePreviewText(
        shopName: shopName,
        shopPhone: shopPhone,
        shopGstin: shopGstin,
        shopAddress: shopAddress,
        billerName: billerName,
      ),
    );
  }

  static Future<Uint8List> buildSampleBytes({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
    bool includeLogo = true,
  }) async {
    final layout = _ColumnLayout(widthDots);
    final lines = <_EscPosLine>[];

    for (final title in _headerTitleLines(
      shopName.trim().isEmpty ? 'Maran Veterinary Hospital' : shopName,
    )) {
      lines.add(_EscPosLine(title, font: titleFont, align: _Align.center));
    }
    lines.add(const _EscPosLine(''));

    final address = (shopAddress ??
            'Vimaladevi Complex, Kanji Road, Vengikkal, Tiruvannamalai.')
        .trim();
    for (final part in _addressTwoLines(address)) {
      lines.add(_EscPosLine(part, align: _Align.center));
    }
    lines.add(
      _EscPosLine(
        'Ph :${(shopPhone ?? '9488350208').trim()}',
        align: _Align.center,
      ),
    );
    final gstin = (shopGstin ?? '').trim();
    if (gstin.isNotEmpty) {
      lines.add(_EscPosLine('GST No :$gstin', align: _Align.center));
    }
    lines.add(const _EscPosLine(''));
    lines.add(_EscPosLine('CASH BILL', font: titleFont, align: _Align.center));
    lines.add(const _EscPosLine(''));

    final biller = (billerName ?? 'user1').trim();
    lines.add(
      _EscPosLine('Biller : $biller', rightText: 'Date : 26.10.2025'),
    );
    lines.add(
      _EscPosLine('Bill NO. : 20-21/46916', rightText: 'Time : 12:35 PM'),
    );
    lines.add(_EscPosLine('Cus Name : sivaraman'));
    lines.add(const _EscPosLine(''));

    lines.add(_EscPosLine.rule(layout.ruleWidthDots));
    lines.add(
      _EscPosLine.item(
        sno: 'No',
        name: 'Particulars',
        mrp: 'MRP',
        price: 'Price',
        qty: 'Qty',
        amt: 'Amt',
      ),
    );
    lines.add(_EscPosLine.rule(layout.ruleWidthDots));

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
        _EscPosLine.item(
          sno: '${i + 1}.',
          name: it.name,
          mrp: it.mrp,
          price: it.price,
          qty: it.qty,
          amt: it.amt,
        ),
      );
    }
    lines.add(_EscPosLine.rule(layout.ruleWidthDots));
    lines.add(
      _EscPosLine(
        'Bill Amount : 1267.00',
        font: titleFont,
        align: _Align.right,
        pinRight: true,
      ),
    );
    lines.add(_EscPosLine('No Of Items :6'));
    lines.add(_EscPosLine('Grand Total : 1267.00'));
    lines.add(const _EscPosLine(''));
    lines.add(
      _EscPosLine('**** We care for your pet ****', align: _Align.center),
    );
    lines.add(const _EscPosLine(''));
    lines.add(const _EscPosLine(''));
    lines.add(const _EscPosLine(''));

    return _encodeBytes(lines: lines, includeLogo: includeLogo);
  }

  static String _samplePreviewText({
    required String shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    String? billerName,
  }) {
    final titles = _headerTitleLines(
      shopName.trim().isEmpty ? 'Maran Veterinary Hospital' : shopName,
    );
    final addressLines = _addressTwoLines(
      (shopAddress ??
              'Vimaladevi Complex, Kanji Road, Vengikkal, Tiruvannamalai.')
          .trim(),
    );
    final phone = (shopPhone ?? '9488350208').trim();
    final gstin = (shopGstin ?? '').trim();
    final biller = (billerName ?? 'user1').trim();
    return [
      'ESC/POS raster · 80 mm · 576 dots · GS v 0',
      '',
      ...titles,
      ...addressLines,
      'Ph :$phone',
      if (gstin.isNotEmpty) 'GST No :$gstin',
      '',
      'CASH BILL',
      'Biller : $biller                    Date : 26.10.2025',
      'Bill NO. : 20-21/46916              Time : 12:35 PM',
      'Cus Name : sivaraman',
      '----------------------------------------',
      'No  Particulars           MRP   Price Qty    Amt',
      '----------------------------------------',
      '1.  Recombitek C4       820.00  650.00  1  650.00',
      '2.  Deworming            50.00   50.00  1   50.00',
      '3.  Treatment (P4)      250.00  250.00  1  250.00',
      '4.  skyworm dog.         52.00   50.00  1   50.00',
      '5.  belt                 60.00   57.00  1   57.00',
      '6.  Brass Hook Chain No.1 220.00 210.00  1  210.00',
      '----------------------------------------',
      '                         Bill Amount : 1267.00',
      'No Of Items :6',
      'Grand Total : 1267.00',
      '',
      '**** We care for your pet ****',
    ].join('\n');
  }

  static List<String> _headerTitleLines(String? shopName) {
    final raw = (shopName ?? 'Maran Veterinary Hospital').trim();
    if (raw.isEmpty) return const ['MARAN VETERINARY HOSPITAL'];
    return [raw.toUpperCase()];
  }

  static String _billTitle(Invoice invoice) {
    final payments = (invoice.payments ?? const <InvoicePayment>[])
        .where((p) => !p.isCancelled)
        .toList();
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

  static int _charHeight(int font) {
    return (_fontSize(font) * 1.1).round().clamp(16, 36);
  }

  static String _money(double amount) => amount.toStringAsFixed(2);

  static String _qty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(1);
  }

  /// Street on line 1, locality + pincode on line 2 (never more than two lines).
  static List<String> _addressTwoLines(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return const [];

    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 2) return parts;

    final pinIdx = parts.lastIndexWhere(
      (p) => RegExp(r'^\d{6}$').hasMatch(p.replaceAll(' ', '')),
    );
    if (pinIdx >= 1) {
      var line2Start = pinIdx;
      if (pinIdx >= 2) line2Start = pinIdx - 2;
      else if (pinIdx >= 1) line2Start = pinIdx - 1;
      if (line2Start < 1) line2Start = 1;
      return [
        parts.sublist(0, line2Start).join(', '),
        parts.sublist(line2Start).join(', '),
      ];
    }

    final mid = (parts.length / 2).ceil().clamp(1, parts.length - 1);
    return [
      parts.sublist(0, mid).join(', '),
      parts.sublist(mid).join(', '),
    ];
  }

  static Future<Uint8List> _encodeBytes({
    required List<_EscPosLine> lines,
    required bool includeLogo,
  }) async {
    final useTimes = times_font.TsplTimesRenderer.isSupported;
    if (!useTimes) {
      return _encodeTextBytes(lines: lines, includeLogo: includeLogo);
    }

    final centerWidth = widthDots - _amtRightPadDots;
    final layout = _ColumnLayout(widthDots);
    const widthBytes = widthDots ~/ 8;

    _LogoRaster? logo;
    if (includeLogo) {
      await logo_loader.ensureTsplLogoLoaded();
      logo = _packLogoEscPos();
    }

    final cmd = BytesBuilder(copy: false);
    // ESC @ — initialize
    cmd.add(const [0x1B, 0x40]);
    // GS L 0,0 — left margin
    cmd.add(const [0x1D, 0x4C, 0x00, 0x00]);

    if (logo != null && logo.heightDots > 0) {
      final logoX = ((centerWidth - logo.widthDots) / 2).round().clamp(
            0,
            centerWidth,
          );
      final stripH = logo.heightDots + 6;
      final strip = Uint8List(widthBytes * stripH);
      _stampPacked(
        dest: strip,
        destWidthBytes: widthBytes,
        destHeight: stripH,
        packed: logo.packed,
        srcWidthBytes: logo.widthBytes,
        srcWidthDots: logo.widthDots,
        srcHeight: logo.heightDots,
        x: logoX,
        y: 0,
        tsplBits: false,
      );
      _writeRaster(cmd, strip, widthBytes, stripH);
    }

    for (final line in lines) {
      if (line.text.isEmpty &&
          line.rightText == null &&
          line.item == null &&
          line.ruleWidthDots == null) {
        _writeRaster(
          cmd,
          Uint8List(widthBytes * _blankRowDots),
          widthBytes,
          _blankRowDots,
        );
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
        final h = (glyph?.heightDots ?? _charHeight(bodyFont)) + _lineGap;
        final strip = Uint8List(widthBytes * h);
        if (glyph != null) {
          _stampGlyph(strip, widthBytes, h, glyph, 0, 0);
        }
        _writeRaster(cmd, strip, widthBytes, h);
        continue;
      }

      if (line.item != null) {
        final item = line.item!;
        final cells = <({int x, times_font.TsplTimesGlyph glyph})>[];
        var rowH = _charHeight(bodyFont);

        Future<void> placeLeft(String text, int x, int maxW) async {
          if (text.isEmpty || !useTimes) return;
          final g = await times_font.TsplTimesRenderer.render(
            text: text,
            fontSize: size,
            bold: bold,
            maxWidthDots: maxW,
          );
          if (g != null) {
            cells.add((x: x, glyph: g));
            if (g.heightDots > rowH) rowH = g.heightDots;
          }
        }

        Future<void> placeRight(String text, int rightEdge, int maxW) async {
          if (text.isEmpty || !useTimes) return;
          final g = await times_font.TsplTimesRenderer.render(
            text: text,
            fontSize: size,
            bold: bold,
            maxWidthDots: maxW,
          );
          if (g != null) {
            final x = (rightEdge - g.widthDots).clamp(0, rightEdge);
            cells.add((x: x, glyph: g));
            if (g.heightDots > rowH) rowH = g.heightDots;
          }
        }

        await placeLeft(item.sno, layout.snoX, layout.snoW);
        await placeLeft(item.name, layout.nameX, layout.nameW);
        await placeRight(item.mrp, layout.mrpRight, layout.numW);
        await placeRight(item.price, layout.priceRight, layout.numW);
        await placeRight(item.qty, layout.qtyRight, layout.qtyW);
        await placeRight(item.amt, layout.amtRight, layout.amtW);

        final h = rowH + _lineGap;
        final strip = Uint8List(widthBytes * h);
        for (final cell in cells) {
          _stampGlyph(strip, widthBytes, h, cell.glyph, cell.x, 0);
        }
        _writeRaster(cmd, strip, widthBytes, h);
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
      final h = rowH + _lineGap;
      final strip = Uint8List(widthBytes * h);

      if (line.rightText != null) {
        final rightPad =
            line.pinRight ? _amtRightPadDots : _metaRightPadDots;
        final rightEdge = widthDots - rightPad;
        if (leftGlyph != null) {
          _stampGlyph(strip, widthBytes, h, leftGlyph, _marginX, 0);
        }
        if (rightGlyph != null) {
          final rx = (rightEdge - rightGlyph.widthDots).clamp(0, rightEdge);
          _stampGlyph(strip, widthBytes, h, rightGlyph, rx, 0);
        }
      } else if (leftGlyph != null) {
        final int x;
        switch (line.align) {
          case _Align.center:
            x = ((centerWidth - leftGlyph.widthDots) / 2)
                .round()
                .clamp(0, centerWidth);
          case _Align.right:
            final edge = line.pinRight
                ? widthDots - _amtRightPadDots
                : widthDots - _metaRightPadDots;
            x = (edge - leftGlyph.widthDots - _marginX).clamp(0, edge);
          case _Align.left:
            x = _marginX;
        }
        _stampGlyph(strip, widthBytes, h, leftGlyph, x, 0);
      }

      _writeRaster(cmd, strip, widthBytes, h);
    }

    // Feed past the tear bar, then partial cut (GS V 66 n).
    cmd.add(const [0x1B, 0x64, 0x04]);
    cmd.add(const [0x1D, 0x56, 0x42, 0x00]);
    return cmd.toBytes();
  }

  /// Native ESC/POS text (48-col Font A) when Times raster is unavailable.
  static Future<Uint8List> _encodeTextBytes({
    required List<_EscPosLine> lines,
    required bool includeLogo,
  }) async {
    const cols = 48;
    _LogoRaster? logo;
    if (includeLogo) {
      await logo_loader.ensureTsplLogoLoaded();
      logo = _packLogoEscPos();
    }

    final cmd = BytesBuilder(copy: false);
    cmd.add(const [0x1B, 0x40]);
    cmd.add(const [0x1D, 0x4C, 0x00, 0x00]);

    if (logo != null && logo.heightDots > 0) {
      const pageWidthBytes = widthDots ~/ 8;
      final logoX =
          ((widthDots - logo.widthDots) / 2).round().clamp(0, widthDots);
      final stripH = logo.heightDots + 6;
      final strip = Uint8List(pageWidthBytes * stripH);
      _stampPacked(
        dest: strip,
        destWidthBytes: pageWidthBytes,
        destHeight: stripH,
        packed: logo.packed,
        srcWidthBytes: logo.widthBytes,
        srcWidthDots: logo.widthDots,
        srcHeight: logo.heightDots,
        x: logoX,
        y: 0,
        tsplBits: false,
      );
      _writeRaster(cmd, strip, pageWidthBytes, stripH);
    }

    void writeLine(String text) {
      cmd.add(latin1.encode('$text\n'));
    }

    void setAlign(_Align align) {
      final n = switch (align) {
        _Align.center => 1,
        _Align.right => 2,
        _Align.left => 0,
      };
      cmd.add([0x1B, 0x61, n]);
    }

    void setTitle(bool on) {
      cmd.add([0x1B, 0x21, on ? 0x38 : 0x00]);
    }

    for (final line in lines) {
      if (line.text.isEmpty &&
          line.rightText == null &&
          line.item == null &&
          line.ruleWidthDots == null) {
        writeLine('');
        continue;
      }

      if (line.ruleWidthDots != null) {
        setAlign(_Align.left);
        setTitle(false);
        writeLine('-' * cols);
        continue;
      }

      if (line.item != null) {
        final item = line.item!;
        setAlign(_Align.left);
        setTitle(false);
        writeLine(
          _itemRow(
            sno: item.sno,
            name: item.name,
            mrp: item.mrp,
            price: item.price,
            qty: item.qty,
            amt: item.amt,
          ),
        );
        continue;
      }

      final isTitle = line.font == titleFont;
      setTitle(isTitle);
      if (line.rightText != null) {
        setAlign(_Align.left);
        writeLine(_pairRow(line.text, line.rightText!, cols));
      } else {
        setAlign(line.align);
        writeLine(line.text);
      }
      setTitle(false);
    }

    cmd.add(const [0x1B, 0x64, 0x04]);
    cmd.add(const [0x1D, 0x56, 0x42, 0x00]);
    return cmd.toBytes();
  }

  static String _pairRow(String left, String right, int cols) {
    final l = left.trimRight();
    final r = right.trim();
    if (l.length + r.length + 1 >= cols) {
      return '$l $r';
    }
    final pad = cols - l.length - r.length;
    return '$l${' ' * pad}$r';
  }

  static String _itemRow({
    required String sno,
    required String name,
    required String mrp,
    required String price,
    required String qty,
    required String amt,
  }) {
    String padLeft(String v, int w) =>
        v.length >= w ? v.substring(0, w) : v.padRight(w);
    String padRight(String v, int w) =>
        v.length >= w ? v.substring(0, w) : v.padLeft(w);
    return '${padLeft(sno, 3)}'
        '${padLeft(name, 16)}'
        '${padRight(mrp, 8)}'
        '${padRight(price, 8)}'
        '${padRight(qty, 4)}'
        '${padRight(amt, 9)}';
  }

  static void _writeRaster(
    BytesBuilder cmd,
    Uint8List packed,
    int widthBytes,
    int height,
  ) {
    if (height <= 0) return;
    final xL = widthBytes & 0xFF;
    final xH = (widthBytes >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;
    cmd
      ..add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH])
      ..add(packed);
  }

  /// TSPL glyphs use bit 0 = black. ESC/POS GS v 0 uses bit 1 = black.
  static void _stampGlyph(
    Uint8List dest,
    int destWidthBytes,
    int destHeight,
    times_font.TsplTimesGlyph glyph,
    int x,
    int y,
  ) {
    _stampPacked(
      dest: dest,
      destWidthBytes: destWidthBytes,
      destHeight: destHeight,
      packed: glyph.packed,
      srcWidthBytes: glyph.widthBytes,
      srcWidthDots: glyph.widthDots,
      srcHeight: glyph.heightDots,
      x: x,
      y: y,
      tsplBits: true,
    );
  }

  static void _stampPacked({
    required Uint8List dest,
    required int destWidthBytes,
    required int destHeight,
    required Uint8List packed,
    required int srcWidthBytes,
    required int srcWidthDots,
    required int srcHeight,
    required int x,
    required int y,
    required bool tsplBits,
  }) {
    final destWidthDots = destWidthBytes * 8;
    for (var row = 0; row < srcHeight; row++) {
      final dy = y + row;
      if (dy < 0 || dy >= destHeight) continue;
      for (var col = 0; col < srcWidthDots; col++) {
        final dx = x + col;
        if (dx < 0 || dx >= destWidthDots) continue;
        final srcByte = packed[row * srcWidthBytes + (col >> 3)];
        final bitOn = (srcByte & (0x80 >> (col & 7))) != 0;
        final isBlack = tsplBits ? !bitOn : bitOn;
        if (!isBlack) continue;
        dest[dy * destWidthBytes + (dx >> 3)] |= 0x80 >> (dx & 7);
      }
    }
  }

  static _LogoRaster? _packLogoEscPos() {
    final png = TsplLogoBitmap.pngBytes;
    if (png == null || png.isEmpty) return null;
    final decoded = img.decodeImage(png);
    if (decoded == null) return null;

    final rgba = decoded.numChannels == 4
        ? decoded
        : decoded.convert(numChannels: 4);
    var work = img.copyResize(
      rgba,
      width: TsplLogoBitmap.maxWidthDots,
      interpolation: img.Interpolation.nearest,
    );
    work = img.grayscale(work);
    work = img.adjustColor(work, contrast: 2);

    final w = work.width;
    final h = work.height;
    final widthBytes = (w + 7) ~/ 8;
    final packed = Uint8List(widthBytes * h);

    for (var row = 0; row < h; row++) {
      for (var col = 0; col < w; col++) {
        final p = work.getPixel(col, row);
        if (p.a < 128) continue;
        final lum = img.getLuminanceRgb(p.r.toInt(), p.g.toInt(), p.b.toInt());
        if (lum >= 200) continue;
        packed[row * widthBytes + (col >> 3)] |= 0x80 >> (col & 7);
      }
    }

    return _LogoRaster(
      packed: packed,
      widthDots: w,
      heightDots: h,
      widthBytes: widthBytes,
    );
  }
}

class EscPosSampleBuild {
  const EscPosSampleBuild({required this.bytes, required this.preview});

  final Uint8List bytes;
  final String preview;
}

class _LogoRaster {
  const _LogoRaster({
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

class _ColumnLayout {
  _ColumnLayout(this.widthDots)
      : amtRight = widthDots - EscPosReceiptBuilder._amtRightPadDots,
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
    addressCols = (widthDots / (EscPosReceiptBuilder.bodyFontPt * 0.42))
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

class _EscPosLine {
  const _EscPosLine(
    this.text, {
    this.font = EscPosReceiptBuilder.bodyFont,
    this.align = _Align.left,
    this.rightText,
    this.pinRight = false,
    this.item,
    this.ruleWidthDots,
  });

  factory _EscPosLine.item({
    required String sno,
    required String name,
    required String mrp,
    required String price,
    required String qty,
    required String amt,
  }) {
    return _EscPosLine(
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

  factory _EscPosLine.rule(int widthDots) {
    return _EscPosLine('', ruleWidthDots: widthDots);
  }

  final String text;
  final int font;
  final _Align align;
  final String? rightText;
  final bool pinRight;
  final _ItemCols? item;
  final int? ruleWidthDots;
}
