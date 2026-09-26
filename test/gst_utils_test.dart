import 'package:flutter_test/flutter_test.dart';
import 'package:maran/core/utils/gst_utils.dart';

void main() {
  group('GstUtils.roundMoney matches the backend (PHP round)', () {
    test('rounds binary-float halves up', () {
      expect(GstUtils.roundMoney(4.975), 4.98);
      expect(GstUtils.roundMoney(1.005), 1.01);
      expect(GstUtils.roundMoney(-1.005), -1.01);
      expect(GstUtils.roundMoney(2), 2);
      expect(GstUtils.calculateGST(99.5, 5), 4.98);
    });
  });

  group('bill discount applies before tax', () {
    test('10% off ₹100 @ 18% → GST 16.20', () {
      final lines = GstUtils.taxLinesAfterDiscount(
        [(taxable: 100.0, cgstRate: 9.0, sgstRate: 9.0, cgst: 9.0, sgst: 9.0)],
        10,
      );
      expect(lines.single.taxable, 90);
      expect(lines.single.cgst + lines.single.sgst, closeTo(16.2, 0.001));
    });

    test('flat discount split by taxable value; shares sum exactly', () {
      final lines = GstUtils.taxLinesAfterDiscount(
        [
          (taxable: 100.0, cgstRate: 9.0, sgstRate: 9.0, cgst: 9.0, sgst: 9.0),
          (taxable: 300.0, cgstRate: 2.5, sgstRate: 2.5, cgst: 7.5, sgst: 7.5),
        ],
        40,
      );
      expect(lines[0].taxable, 90);
      expect(lines[1].taxable, 270);
      final gst = lines.fold(0.0, (s, l) => s + l.cgst + l.sgst);
      expect(gst, closeTo(29.7, 0.001));
    });

    test('no discount leaves lines untouched', () {
      final lines = GstUtils.taxLinesAfterDiscount(
        [(taxable: 50.0, cgstRate: 9.0, sgstRate: 9.0, cgst: 4.5, sgst: 4.5)],
        0,
      );
      expect(lines.single.taxable, 50);
      expect(lines.single.cgst, 4.5);
    });
  });
}
