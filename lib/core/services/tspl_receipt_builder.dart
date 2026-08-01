import 'dart:convert';

import '../../data/models/invoice.dart';

/// Builds TSPL command bytes for a 203 dpi USB thermal / label printer
/// (e.g. Xprinter XP-470B).
///
/// At 203 dpi: 1 mm ≈ 8 dots.
class TsplReceiptBuilder {
  TsplReceiptBuilder._();

  static const int dpi = 203;
  static const int dotsPerMm = 8;

  /// Built-in font "2" = 12×20 dots; "3" = 16×24 dots.
  static const int _font2CharW = 12;
  static const int _font2CharH = 20;
  static const int _font3CharW = 16;
  static const int _font3CharH = 24;
  static const int _lineGap = 4;

  static List<int> build({
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? shopName,
    String? shopPhone,
    String? shopGstin,
    String? shopAddress,
    int paperWidthMm = 80,
  }) {
    final widthMm = paperWidthMm <= 58 ? 58 : 80;
    final widthDots = widthMm * dotsPerMm;
    final cols = _charsPerLine(widthDots, _font2CharW);
    final lines = <_TsplLine>[];

    final name = (shopName ?? 'Maran Billing').trim();
    lines.add(_TsplLine(name, font: 3, align: _Align.center, bold: true));
    if (shopAddress != null && shopAddress.trim().isNotEmpty) {
      for (final part in _wrap(shopAddress.trim(), cols)) {
        lines.add(_TsplLine(part, align: _Align.center));
      }
    }
    if (shopPhone != null && shopPhone.trim().isNotEmpty) {
      lines.add(_TsplLine(shopPhone.trim(), align: _Align.center));
    }
    lines.add(_TsplLine(_hr(cols)));

    lines.add(_TsplLine('Inv: ${invoice.invoiceNumber}', bold: true));
    lines.add(_TsplLine('Date: ${invoice.displayDate}'));
    lines.add(_TsplLine('Status: ${invoice.status.toUpperCase()}'));
    lines.add(_TsplLine(_hr(cols)));

    final customer = invoice.customer;
    if (customer != null) {
      lines.add(_TsplLine('Customer: ${customer.name}'));
      if (customer.phone.isNotEmpty) {
        lines.add(_TsplLine('Phone: ${customer.phone}'));
      }
      lines.add(_TsplLine(_hr(cols)));
    }

    lines.add(_TsplLine(_itemHeader(cols), bold: true));
    lines.add(_TsplLine(_hr(cols, ch: '-')));

    for (final item in items) {
      final mrp = item.mrp > 0 ? item.mrp : item.unitPrice;
      final qty = item.quantity.toStringAsFixed(
        item.quantity == item.quantity.roundToDouble() ? 0 : 1,
      );
      lines.add(
        _TsplLine(
          _itemRow(
            cols,
            name: item.productName,
            mrp: _money(mrp),
            rate: _money(item.unitPrice),
            qty: qty,
            amt: item.totalAmount.toStringAsFixed(2),
          ),
        ),
      );
    }
    lines.add(_TsplLine(_hr(cols)));

    lines.add(_TsplLine(_moneyRow(cols, 'Subtotal', invoice.subtotal)));
    if (invoice.discountAmount > 0) {
      lines.add(_TsplLine(_moneyRow(cols, 'Discount', -invoice.discountAmount)));
    }
    if (invoice.roundOff != 0) {
      lines.add(_TsplLine(_moneyRow(cols, 'Round Off', invoice.roundOff)));
    }
    lines.add(_TsplLine(_hr(cols, ch: '=')));
    lines.add(
      _TsplLine(
        'TOTAL  Rs ${invoice.totalAmount.toStringAsFixed(2)}',
        font: 3,
        align: _Align.right,
        bold: true,
      ),
    );

    final payments = (invoice.payments ?? const <InvoicePayment>[])
        .where((p) => p.amount > 0.009)
        .toList();
    if (payments.isNotEmpty) {
      lines.add(_TsplLine(_hr(cols, ch: '-')));
      for (final p in payments) {
        final mode = switch (p.paymentMode.toLowerCase()) {
          'cash' => 'Cash',
          'upi' => 'UPI',
          'card' => 'Card',
          'bank_transfer' => 'Bank',
          'cheque' => 'Cheque',
          'loyalty_points' => 'Loyalty',
          'advance' => 'Advance',
          _ => p.paymentMode,
        };
        lines.add(_TsplLine(_moneyRow(cols, mode, p.amount)));
        if (p.hasCashTenderDetail) {
          lines.add(_TsplLine(_moneyRow(cols, '  Cash received', p.tenderedAmount!)));
          lines.add(_TsplLine(_moneyRow(cols, '  Change given', p.changeReturn!)));
        }
        if (p.referenceNumber != null && p.referenceNumber!.trim().isNotEmpty) {
          lines.add(_TsplLine('  Ref: ${p.referenceNumber}'));
        }
      }
      if (invoice.dueAmount > 0.009) {
        lines.add(_TsplLine(_moneyRow(cols, 'Balance due', invoice.dueAmount)));
      }
    } else {
      final cashPayments = (invoice.payments ?? const <InvoicePayment>[])
          .where((p) => p.hasCashTenderDetail)
          .toList();
      if (cashPayments.isNotEmpty) {
        lines.add(_TsplLine(_hr(cols, ch: '-')));
        for (final p in cashPayments) {
          lines.add(_TsplLine(_moneyRow(cols, 'Cash received', p.tenderedAmount!)));
          lines.add(_TsplLine(_moneyRow(cols, 'Change given', p.changeReturn!)));
        }
      }
    }

    lines.add(_TsplLine(_hr(cols)));
    lines.add(_TsplLine('Thank you!', align: _Align.center, bold: true));
    lines.add(_TsplLine('Visit again soon', align: _Align.center));
    lines.add(_TsplLine('Powered by bestwaveinnovation.com', align: _Align.center));

    return _encode(widthMm: widthMm, widthDots: widthDots, lines: lines);
  }

  /// Hardware / sample bill for settings Test Print.
  static List<int> buildSample({
    required String shopName,
    int paperWidthMm = 80,
  }) {
    return latin1.encode(buildSampleCommands(
      shopName: shopName,
      paperWidthMm: paperWidthMm,
    ));
  }

  /// Same sample as [buildSample], as readable TSPL text for UI preview.
  static String buildSampleCommands({
    required String shopName,
    int paperWidthMm = 80,
  }) {
    final widthMm = paperWidthMm <= 58 ? 58 : 80;
    final widthDots = widthMm * dotsPerMm;
    final cols = _charsPerLine(widthDots, _font2CharW);
    final lines = <_TsplLine>[
      _TsplLine(
        shopName.trim().isEmpty ? 'Maran Billing' : shopName.trim(),
        font: 3,
        align: _Align.center,
        bold: true,
      ),
      _TsplLine('SAMPLE BILL', font: 3, align: _Align.center, bold: true),
      _TsplLine('TSPL · 203 dpi', align: _Align.center),
      _TsplLine(_hr(cols)),
      _TsplLine(_itemHeader(cols), bold: true),
      _TsplLine(_hr(cols, ch: '-')),
      _TsplLine(
        _itemRow(cols, name: 'Consult', mrp: '300', rate: '300', qty: '1', amt: '300.00'),
      ),
      _TsplLine(
        _itemRow(cols, name: 'Suture', mrp: '220', rate: '200', qty: '2', amt: '400.00'),
      ),
      _TsplLine(_hr(cols)),
      _TsplLine('TOTAL  Rs 700.00', font: 3, align: _Align.right, bold: true),
      _TsplLine('USB thermal test OK', align: _Align.center),
      _TsplLine('Powered by bestwaveinnovation.com', align: _Align.center),
    ];
    return _encodeCommands(widthMm: widthMm, widthDots: widthDots, lines: lines);
  }

  static List<int> _encode({
    required int widthMm,
    required int widthDots,
    required List<_TsplLine> lines,
  }) {
    return latin1.encode(
      _encodeCommands(widthMm: widthMm, widthDots: widthDots, lines: lines),
    );
  }

  static String _encodeCommands({
    required int widthMm,
    required int widthDots,
    required List<_TsplLine> lines,
  }) {
    final marginX = 8;
    final marginY = 16;
    var y = marginY;
    final cmd = StringBuffer();

    // Height from content + bottom margin (continuous / gap-less label).
    final contentHeight = lines.fold<int>(0, (sum, l) => sum + l.heightDots + _lineGap);
    final heightDots = contentHeight + marginY * 2;
    final heightMm = ((heightDots / dotsPerMm).ceil()).clamp(40, 600);

    cmd.writeln('SIZE $widthMm mm, $heightMm mm');
    cmd.writeln('GAP 0 mm, 0 mm');
    cmd.writeln('DIRECTION 1');
    cmd.writeln('REFERENCE 0,0');
    cmd.writeln('SET TEAR ON');
    cmd.writeln('CLS');

    for (final line in lines) {
      final fontName = '"${line.font}"';
      final charW = line.font == 3 ? _font3CharW : _font2CharW;
      final text = _escape(line.text);
      final textDots = text.length * charW * line.xMul;
      final int x;
      switch (line.align) {
        case _Align.center:
          x = ((widthDots - textDots) / 2).round().clamp(0, widthDots);
        case _Align.right:
          x = (widthDots - textDots - marginX).clamp(0, widthDots);
        case _Align.left:
          x = marginX;
      }
      cmd.writeln(
        'TEXT $x,$y,$fontName,0,${line.xMul},${line.yMul},"$text"',
      );
      y += line.heightDots + _lineGap;
    }

    cmd.writeln('PRINT 1,1');
    return cmd.toString();
  }

  static int _charsPerLine(int widthDots, int charW) {
    final usable = widthDots - 16;
    return (usable / charW).floor().clamp(24, 64);
  }

  static String _hr(int cols, {String ch = '-'}) => ch * cols;

  static String _itemHeader(int cols) {
    // Item | MRP | Rate | Qty | Amt
    return _columns(cols, const ['Item', 'MRP', 'Rate', 'Qty', 'Amt']);
  }

  static String _itemRow(
    int cols, {
    required String name,
    required String mrp,
    required String rate,
    required String qty,
    required String amt,
  }) {
    final nameW = (cols * 0.34).round().clamp(6, 20);
    return _columns(cols, [_clip(name, nameW), mrp, rate, qty, amt]);
  }

  static String _columns(int cols, List<String> parts) {
    // 5 columns: flexible first, fixed-ish numeric rest.
    final numW = 6;
    final qtyW = 4;
    final fixed = numW * 3 + qtyW;
    final itemW = (cols - fixed).clamp(4, cols);
    final widths = [itemW, numW, numW, qtyW, numW];
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final w = widths[i];
      final raw = parts[i];
      if (i == 0) {
        buf.write(_padRight(_clip(raw, w), w));
      } else {
        buf.write(_padLeft(_clip(raw, w), w));
      }
    }
    final s = buf.toString();
    return s.length > cols ? s.substring(0, cols) : s;
  }

  static String _moneyRow(int cols, String label, double amount) {
    final amt = amount.toStringAsFixed(2);
    final labelW = cols - amt.length;
    if (labelW <= 0) return amt;
    return '${_padRight(_clip(label, labelW), labelW)}$amt';
  }

  static String _money(double amount) => amount.toStringAsFixed(2);

  static String _clip(String value, int max) {
    final t = value.trim();
    if (max <= 0) return '';
    if (t.length <= max) return t;
    if (max == 1) return t.substring(0, 1);
    return '${t.substring(0, max - 1)}.';
  }

  static String _padLeft(String s, int w) {
    if (s.length >= w) return s;
    return s.padLeft(w);
  }

  static String _padRight(String s, int w) {
    if (s.length >= w) return s;
    return s.padRight(w);
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

  /// TSPL TEXT strings use double quotes — strip / replace quotes in content.
  static String _escape(String value) {
    return value.replaceAll('"', "'").replaceAll('\r', ' ').replaceAll('\n', ' ');
  }
}

enum _Align { left, center, right }

class _TsplLine {
  _TsplLine(
    this.text, {
    this.font = 2,
    this.align = _Align.left,
    this.bold = false,
  });

  final String text;
  final int font;
  final _Align align;
  final bool bold;

  int get xMul => bold && font == 2 ? 1 : 1;
  int get yMul => bold && font == 3 ? 1 : 1;

  int get heightDots {
    final h = font == 3 ? TsplReceiptBuilder._font3CharH : TsplReceiptBuilder._font2CharH;
    return h * yMul;
  }
}
